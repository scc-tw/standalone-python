"""Advertise shipped musl libc to pip/packaging for correct wheel selection.

Background
----------
packaging.tags infers libc by:
  1. trying os.confstr("CS_GNU_LIBC_VERSION") (glibc-only, fails on musl),
  2. parsing PT_INTERP out of sys.executable's ELF header, then running
     that ld.so to read its version from stderr.

In this distribution sys.executable resolves to our static launcher
binary. Static binaries have no PT_INTERP, so step 2 returns None, and
packaging yields no musllinux_*_* tag. pip then picks whatever wheel
claims bare linux_x86_64 compatibility — usually a glibc manylinux
wheel — and on load the runtime hits glibc-only symbols (mallinfo,
__libc_start_main quirks, etc.) that musl does not provide.

Fix
---
The launcher exports two env vars before exec:
  _STANDALONE_PYTHON_MUSL_LD        absolute path to the shipped ld.so
  _STANDALONE_PYTHON_MUSL_VERSION   "MAJOR.MINOR" (compile-time constant)

Both are resolved $ORIGIN-relative by the launcher, so moving the
install somewhere else keeps them correct — no ELF patching, no fixed
absolute install prefix.

This module installs a sys.meta_path finder that wraps the loader for
the relevant packaging submodules. Right after each one finishes
executing, we replace its `_get_musl_version` with a constant that
reflects the shipped musl version.

Modern packaging layouts split `_get_musl_version` across two modules:
  - packaging._musllinux       (the source of truth; _musllinux_platforms
                                inside this module calls it directly)
  - packaging.tags             (re-exports it via `from ._musllinux import
                                _get_musl_version`; kept in sync for
                                external callers that imported it from
                                here historically)
Both need to be patched: `tags` for anything that imports
`_get_musl_version` from there, `_musllinux` for `sys_tags()`'s internal
path via `_musllinux_platforms`. Older packaging versions keep both in
`tags`, so patching both names is harmless when one doesn't exist.

Patching the loader (rather than eagerly importing packaging) keeps
Python startup cheap for callers that never touch pip.
"""

import os
import sys


def _activate(version_str):
    try:
        major, minor = (int(p) for p in version_str.split(".")[:2])
    except (ValueError, TypeError):
        return

    def _patch(module):
        if getattr(module, "_standalone_python_patched", False):
            return
        if not hasattr(module, "_get_musl_version"):
            return
        MuslVersion = getattr(module, "_MuslVersion", None)
        version = MuslVersion(major, minor) if MuslVersion else (major, minor)
        module._get_musl_version = lambda executable=None: version
        module._standalone_python_patched = True

    targets = (
        "pip._vendor.packaging._musllinux",
        "pip._vendor.packaging.tags",
        "packaging._musllinux",
        "packaging.tags",
    )

    for name in targets:
        mod = sys.modules.get(name)
        if mod is not None:
            _patch(mod)

    import importlib.abc

    class _Loader(importlib.abc.Loader):
        def __init__(self, inner):
            self._inner = inner

        def create_module(self, spec):
            if hasattr(self._inner, "create_module"):
                return self._inner.create_module(spec)
            return None

        def exec_module(self, module):
            self._inner.exec_module(module)
            _patch(module)

    class _Finder(importlib.abc.MetaPathFinder):
        def find_spec(self, fullname, path=None, target=None):
            if fullname not in targets:
                return None
            idx = sys.meta_path.index(self)
            for finder in sys.meta_path[idx + 1:]:
                find_spec = getattr(finder, "find_spec", None)
                if find_spec is None:
                    continue
                spec = find_spec(fullname, path, target)
                if spec is None:
                    continue
                spec.loader = _Loader(spec.loader)
                return spec
            return None

    sys.meta_path.insert(0, _Finder())


_version = os.environ.get("_STANDALONE_PYTHON_MUSL_VERSION")
if _version:
    _activate(_version)
