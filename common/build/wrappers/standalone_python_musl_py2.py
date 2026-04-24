# Python 2.7 companion to standalone_python_musl.py.
#
# Responsibilities
# ----------------
# The py3 hook does two things: (1) patch packaging's _get_musl_version to
# advertise the shipped musl version for correct wheel selection, and (2)
# expand an install-prefix sentinel inside sysconfig so `pip install
# foo-from-source` works after the install tree is relocated (e.g. from
# /opt/python to /tmp/mypack/python).
#
# For py2.7 we only need (2). Justification for dropping (1):
#   - pip 20.3.4 (the last py2-compatible release, pinned in
#     install_pip_py2.sh) predates PEP 656 musllinux tag support, so
#     there is no _get_musl_version to patch.
#   - The py2 Dockerfiles already document that users needing native
#     wheels on 2.7 should pass --no-binary :all:.
#
# Relocatability design
# ---------------------
# packing-initializer rewrites `/opt/shared_libraries` (the build-time
# prefix inherited from build_python_py2.sh's LDFLAGS) to the sentinel
# `@STANDALONE_PYTHON_PREFIX@/shared_libraries` in every file that baked
# the old absolute path: `_sysconfigdata.py` (py2's single-module
# equivalent of py3's _sysconfigdata__<platform>_<triple>.py),
# `config/Makefile`, and `python2.7-config`. This .pth-loaded module then
# substitutes `sys.prefix` for the sentinel on every interpreter startup,
# before any caller (pip / distutils / setuptools) reads the config vars.
#
# py2 caches to patch
# -------------------
# Two stdlib caches consume `_sysconfigdata.build_time_vars`:
#   * sysconfig._CONFIG_VARS           (Lib/sysconfig.py)
#   * distutils.sysconfig._config_vars (Lib/distutils/sysconfig.py)
# Both call `_init_posix(vars)` which does `from _sysconfigdata import
# build_time_vars; vars.update(build_time_vars)` on first read. Patching
# build_time_vars before either reads it propagates to both lazily;
# patching a cache that's already been populated (e.g. by another .pth
# that raced us) handles the non-default ordering. The cost is O(keys)
# per dict — negligible at startup.
#
# Intentionally minimal: no try/except importlib.abc dance (py2's
# importlib predates the hooks the py3 file uses, and there's no module
# to lazily patch on import). Plain function, plain imports.

import sys


_SYSCONFIG_PREFIX_SENTINEL = "@STANDALONE_PYTHON_PREFIX@"

# py2.7 stores config-var values as either `str` (bytes) or `unicode`
# depending on how the value was initialized; values that came through
# pprint-serialized _sysconfigdata are normally `str`, but entries a
# site.py hook might have injected could be `unicode`. Match both.
try:
    _TEXT_TYPES = (str, unicode)  # noqa: F821  — py2 only
except NameError:
    _TEXT_TYPES = (str,)


def _patch_dict(d, prefix):
    if not isinstance(d, dict):
        return
    for k, v in list(d.items()):
        if isinstance(v, _TEXT_TYPES) and _SYSCONFIG_PREFIX_SENTINEL in v:
            d[k] = v.replace(_SYSCONFIG_PREFIX_SENTINEL, prefix)


def _expand_sysconfig_prefix():
    prefix = sys.prefix
    if not prefix:
        return

    # Patch build_time_vars directly (source of truth).  If _sysconfigdata
    # isn't importable we still try the two caches below — they may have
    # been populated via an alternate path such as a frozen Makefile parse.
    try:
        import _sysconfigdata
        btv = getattr(_sysconfigdata, "build_time_vars", None)
        _patch_dict(btv, prefix)
    except ImportError:
        pass

    # sysconfig (2.7+) cache.
    try:
        import sysconfig
        _patch_dict(getattr(sysconfig, "_CONFIG_VARS", None), prefix)
    except ImportError:
        pass

    # distutils.sysconfig cache — what pip 20.x actually reads when
    # compiling a source distribution, via distutils.sysconfig.customize_compiler.
    try:
        from distutils import sysconfig as _dsc
        _patch_dict(getattr(_dsc, "_config_vars", None), prefix)
    except ImportError:
        pass


_expand_sysconfig_prefix()
