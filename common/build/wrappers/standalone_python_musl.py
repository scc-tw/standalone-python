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


_SYSCONFIG_PREFIX_SENTINEL = "@STANDALONE_PYTHON_PREFIX@"


def _expand_sysconfig_prefix():
    """Substitute sys.prefix for the build-time prefix sentinel in sysconfig.

    Background
    ----------
    build_python.sh exports `LDFLAGS="-L/opt/shared_libraries/lib -lffi
    -Wl,-rpath,/opt/shared_libraries/lib"` so CPython's own C extensions
    link against the shipped libs at build time. `make install` bakes the
    resulting LDFLAGS into `_sysconfigdata_*.py` under `build_time_vars`
    (and mirror copies in `config-*/Makefile`, `python-config.py`). When
    packing-initializer then moves `/opt/shared_libraries` under
    `/opt/python/`, those absolute paths become dangling.

    Instead of rewriting to a new absolute path (which would re-bake
    /opt/python and break relocation to /tmp/whatever), packing-initializer
    substitutes `/opt/shared_libraries` with the sentinel
    `@STANDALONE_PYTHON_PREFIX@/shared_libraries` in those files, and this
    function expands the sentinel to the live `sys.prefix` on every
    interpreter startup via the .pth hook.

    Why both `build_time_vars` AND `_CONFIG_VARS`:
        sysconfig reads `build_time_vars` on first `get_config_var()` call,
        then caches into `_CONFIG_VARS`. Most callers trigger the first
        read, so patching `build_time_vars` alone is enough. But another
        .pth file or a stdlib init path could have primed `_CONFIG_VARS`
        before us. Patching both covers both orderings and is idempotent.
    """
    try:
        import sysconfig
    except ImportError:
        return

    prefix = sys.prefix
    if not prefix or _SYSCONFIG_PREFIX_SENTINEL not in _probe_sysconfig(sysconfig):
        return

    # Patch build_time_vars (the source of truth for future lookups).
    modname = None
    get_name = getattr(sysconfig, "_get_sysconfigdata_name", None)
    if callable(get_name):
        try:
            modname = get_name()
        except Exception:
            modname = None
    if modname:
        mod = sys.modules.get(modname)
        if mod is None:
            try:
                mod = __import__(modname, fromlist=["build_time_vars"])
            except Exception:
                mod = None
        btv = getattr(mod, "build_time_vars", None) if mod is not None else None
        if isinstance(btv, dict):
            for k, v in list(btv.items()):
                if isinstance(v, str) and _SYSCONFIG_PREFIX_SENTINEL in v:
                    btv[k] = v.replace(_SYSCONFIG_PREFIX_SENTINEL, prefix)

    # Patch the already-populated cache, if any.
    cache = getattr(sysconfig, "_CONFIG_VARS", None)
    if isinstance(cache, dict):
        for k, v in list(cache.items()):
            if isinstance(v, str) and _SYSCONFIG_PREFIX_SENTINEL in v:
                cache[k] = v.replace(_SYSCONFIG_PREFIX_SENTINEL, prefix)


def _probe_sysconfig(sysconfig):
    """Return a concatenated string of LDFLAGS-like vars for sentinel probing.

    Cheap up-front check: if none of the common link/compile-flag vars
    contain the sentinel, we skip the whole module-patching path. This
    keeps startup cost near zero on installs that don't need the fixup
    (e.g. future rebuilds that dropped the sentinel).
    """
    parts = []
    for key in ("LDFLAGS", "LDSHARED", "BLDSHARED", "CFLAGS", "CPPFLAGS", "LIBDIR", "LIBPL"):
        try:
            val = sysconfig.get_config_var(key)
        except Exception:
            val = None
        if isinstance(val, str):
            parts.append(val)
    return "\n".join(parts)


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


# Unconditional: the sysconfig prefix fixup must run on every Python
# startup regardless of whether the launcher set the musl env vars,
# because downstream `pip install` readers don't depend on the launcher.
_expand_sysconfig_prefix()

_version = os.environ.get("_STANDALONE_PYTHON_MUSL_VERSION")
if _version:
    _activate(_version)
