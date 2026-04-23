#!/bin/sh

# https://ftpmirror.gnu.org/gdbm/gdbm-1.23.tar.gz
set -e
export READLINE_VERSION=1.23

wget https://ftp.gnu.org/gnu/gdbm/gdbm-${READLINE_VERSION}.tar.gz
tar -xzf gdbm-${READLINE_VERSION}.tar.gz && cd gdbm-${READLINE_VERSION}

export CFLAGS="${CFLAGS} -fPIC"
./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
