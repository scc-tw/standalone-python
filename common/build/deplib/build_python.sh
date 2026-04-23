#!/bin/sh

set -e
. ./_fetch.sh

export INSTALL_PREFIX=/opt/python
export gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"

tarball="Python-${PYTHON_VERSION}.tar.xz"

fetch_mirrored "$tarball" \
    "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/${tarball}"

tar -xvf "$tarball" && cd "Python-${PYTHON_VERSION}"


export EXTRA_CFLAGS="-DTHREAD_STACK_SIZE=0x100000"
export LDFLAGS="${LDFLAGS:--Wl},--strip-all"

# Our ncurses is built with --enable-widec (ncurses 6.x default), which
# installs headers under `include/ncursesw/` (not `include/ncurses/`) and
# exposes libncursesw.so. Without this include path Python's setup.py
# can't find `curses.h` and silently skips building `_curses` /
# `_curses_panel` / `readline` wide-char bits.
export LOCAL_INCLUDES="-I/opt/shared_libraries/include/ncursesw"
export LOCAL_INCLUDES="${LOCAL_INCLUDES} -I/opt/shared_libraries/include/" # some wired packages include ncurses.h or ncurses/ncurses.h

export CFLAGS="${CFLAGS} ${LOCAL_INCLUDES}"
export CPPFLAGS="${CPPFLAGS} ${LOCAL_INCLUDES}"
# Bake an absolute rpath to /opt/shared_libraries/lib into every C extension
# linked during this build. --with-openssl-rpath=auto only handles OpenSSL;
# other extensions (_curses→libtinfo, _sqlite3→libsqlite3, readline→libreadline,
# _ctypes→libffi, …) have no CPython-level flag to set their rpath, so
# without this the build's own `sysconfig --generate-posix-vars` import test
# fails with "Error loading shared library libtinfo.so.6: No such file".
# rpath-patcher.sh rewrites this to $ORIGIN-relative after packing, so the
# final image stays relocatable.
export LDFLAGS="${LDFLAGS} -L/opt/shared_libraries/lib -lffi -Wl,-rpath,/opt/shared_libraries/lib"

# Free-threaded build (PEP 703 / "no-GIL"), added in Python 3.13. Enabled
# per-Dockerfile with `ENV DISABLE_GIL=1` in the python_builder stage. The
# resulting install has python3.Nt binaries, libpython3.Nt.so.1.0, and
# lib/python3.Nt/ site-packages (ABI tag "t" distinguishes them from the
# GIL build). Passing --disable-gil to CPython < 3.13 will fail
# --enable-option-checking=fatal, which is the behaviour we want.
CONFIGURE_EXTRA=""
if [ "${DISABLE_GIL:-0}" = "1" ]; then
    CONFIGURE_EXTRA="--disable-gil"
fi

# PGO exclusions for the musl (Alpine) base. The default PROFILE_TASK from
# configure.ac is `-m test --pgo --timeout=$(TESTTIMEOUT)`; we append -x
# flags for tests that fail during profile generation because of musl
# limitations rather than CPython regressions. Alpine aports follows the
# same pattern (their ppc64le branch excludes `test_time`) but handles
# musl locale breakage in post-build `check()` only because they never
# build 3.13 or free-threaded. We must handle it at PGO time.
#
# test_re: test_locale_caching / test_locale_compiled assume iso8859-1
# case-folding works. musl's LC_CTYPE has no such locale data, so the
# case-insensitive match of `\xc5` ~ `\xe5` fails. Alpine's own check()
# skips the whole test_re module on musl for the same reason. 3.12 passed
# by accident because Modules/_sre/sre.c called libc `tolower` directly;
# 3.13 routes through a `sre_tolower` wrapper that exposes the musl gap.
PGO_EXCLUDES="test_re"

# Per-Dockerfile opt-in for version-specific PGO breakage. Used by 3.14t
# to skip test_struct.test_endian_table_init_subinterpreters, which races
# on importlib._bootstrap_external._fill_cache() under concurrent
# subinterpreter import (upstream gh-140260 / gh-142414). Remove the ENV
# once the upstream fix lands in a 3.14.x point release.
if [ -n "${EXTRA_PGO_EXCLUDES:-}" ]; then
    PGO_EXCLUDES="${PGO_EXCLUDES} ${EXTRA_PGO_EXCLUDES}"
fi

export PROFILE_TASK="-m test --pgo --timeout=\$(TESTTIMEOUT) -x ${PGO_EXCLUDES}"

./configure --build="$gnuArch" --enable-loadable-sqlite-extensions \
    --enable-optimizations --enable-option-checking=fatal --enable-shared \
    --with-lto --with-system-expat --without-ensurepip \
    --with-dbmliborder=gdbm:ndbm \
    --prefix="$INSTALL_PREFIX" --with-openssl-rpath=auto \
    --with-openssl=/opt/shared_libraries \
    $CONFIGURE_EXTRA

make -j $(nproc)
rm python
make -j $(nproc) python
make install
