#!/bin/sh
#
# Build Python 2.7.x against the shared_libraries tree under
# /opt/shared_libraries. Separate from build_python.sh because 2.7's
# configure does not accept several of the Py3-era flags we rely on:
#   --enable-loadable-sqlite-extensions (Py3-only — 2.7 controls this via
#                                        setup.py; loadable extensions are
#                                        enabled as long as the SQLite
#                                        library itself supports them,
#                                        which ours does)
#   --with-openssl=<path>  (added in 3.7 — 2.7's setup.py uses
#                          CPPFLAGS/LDFLAGS instead)
#   --with-openssl-rpath=  (added in 3.7)
#   --without-ensurepip    (added in 3.4; we install pip via get-pip.py anyway)
#
# Note: 2.7.18 DOES backport --enable-optimizations and --with-lto, but
# they roughly double build time; leave them off unless a release needs
# the perf bump. Toggle via PY2_OPTIMIZE=1 below.
#
# Also leaves libffi and expat bundled. 2.7 ships both under Modules/ and
# the in-tree copies are known-good against 2.7's ctypes / pyexpat, whereas
# the current system versions (libffi 3.5, expat 2.7) are beyond what 2.7
# was tested against.

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

# 2.7's setup.py scans CPPFLAGS/LDFLAGS to find OpenSSL / sqlite / ncurses /
# etc. Point those at the shipped prefix so OpenSSL 1.1.1w is discovered.
# Our ncurses is built with --enable-widec (ncurses 6.x default), so
# headers live under `include/ncursesw/` and libraries are `libncursesw*`.
# Without the ncursesw include setup.py silently skips building `_curses`.
export LOCAL_INCLUDES="-I/opt/shared_libraries/include/ncursesw"
export LOCAL_INCLUDES="${LOCAL_INCLUDES} -I/opt/shared_libraries/include/"
export CFLAGS="${CFLAGS} ${LOCAL_INCLUDES}"
export CPPFLAGS="${CPPFLAGS} ${LOCAL_INCLUDES}"
# Bake an absolute rpath into every C extension linked during this build
# (most notably _hashlib.so and _ssl.so). 2.7 has no --with-openssl-rpath
# equivalent, so without this the loader can't resolve libssl.so.1.1 at
# import time — which breaks hashlib, breaks get-pip, breaks everything.
# rpath-patcher.sh rewrites this to $ORIGIN-relative after packing, so the
# final image stays relocatable.
export LDFLAGS="${LDFLAGS} -L/opt/shared_libraries/lib -Wl,-rpath,/opt/shared_libraries/lib"

./configure --build="$gnuArch" \
    --enable-option-checking=fatal \
    --enable-shared \
    --enable-unicode=ucs4 \
    --with-dbmliborder=gdbm:ndbm \
    --prefix="$INSTALL_PREFIX"

make -j $(nproc)
make install
