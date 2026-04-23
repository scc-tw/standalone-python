#!/bin/sh

# https://ftp.gnu.org/gnu/gdbm/gdbm-1.23.tar.gz
set -e
export GDBM_VERSION=${GDBM_VERSION:-1.23}

wget https://ftp.gnu.org/gnu/gdbm/gdbm-${GDBM_VERSION}.tar.gz
tar -xzf gdbm-${GDBM_VERSION}.tar.gz && cd gdbm-${GDBM_VERSION}

export CFLAGS="${CFLAGS} -fPIC"
# --enable-libgdbm-compat exposes gdbm-ndbm.h and libgdbm_compat.so so
# Python's _dbm module (driven by --with-dbmliborder=gdbm:ndbm) can build
# against gdbm. Without it _dbm shows up in the "failed" list at the end
# of `make` — `dbm.gnu` still works (that uses _gdbm), but `dbm.ndbm` and
# the plain `dbm` dispatch path both need this.
./configure --prefix=/opt/shared_libraries --enable-libgdbm-compat
make -j $(nproc) && make install
