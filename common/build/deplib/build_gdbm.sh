#!/bin/sh

set -e
. ./_fetch.sh

export GDBM_VERSION=${GDBM_VERSION:-1.23}
tarball="gdbm-${GDBM_VERSION}.tar.gz"

# GNU mirror chain — ftpmirror.gnu.org is a round-robin redirector that
# already does its own geographic mirror selection; others are stable
# independent mirrors for when ftpmirror's DNS is slow. Verified 2026-04-23.
fetch_mirrored "$tarball" \
    "https://ftpmirror.gnu.org/gdbm/${tarball}" \
    "https://ftp.gnu.org/gnu/gdbm/${tarball}" \
    "https://mirrors.kernel.org/gnu/gdbm/${tarball}" \
    "https://ftp.osuosl.org/pub/gnu/gdbm/${tarball}"

tar -xzf "$tarball" && cd "gdbm-${GDBM_VERSION}"

export CFLAGS="${CFLAGS} -fPIC"
# --enable-libgdbm-compat exposes gdbm-ndbm.h and libgdbm_compat.so so
# Python's _dbm module (driven by --with-dbmliborder=gdbm:ndbm) can build
# against gdbm. Without it _dbm shows up in the "failed" list at the end
# of `make` — `dbm.gnu` still works (that uses _gdbm), but `dbm.ndbm` and
# the plain `dbm` dispatch path both need this.
./configure --prefix=/opt/shared_libraries --enable-libgdbm-compat
make -j $(nproc) && make install
