#!/bin/sh

# https://ftp.gnu.org/gnu/gdbm/gdbm-1.23.tar.gz
set -e
export GDBM_VERSION=${GDBM_VERSION:-1.23}

wget https://ftp.gnu.org/gnu/gdbm/gdbm-${GDBM_VERSION}.tar.gz
tar -xzf gdbm-${GDBM_VERSION}.tar.gz && cd gdbm-${GDBM_VERSION}

export CFLAGS="${CFLAGS} -fPIC"
./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
