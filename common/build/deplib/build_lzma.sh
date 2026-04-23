#!/bin/sh

# https://tukaani.org/lzma/lzma-4.32.7.tar.gz
set -e
export LZMA_VERSION=4.32.7

wget https://tukaani.org/lzma/lzma-${LZMA_VERSION}.tar.gz
tar -xzf lzma-${LZMA_VERSION}.tar.gz && cd lzma-${LZMA_VERSION}

export CFLAGS="${CFLAGS} -fPIC"
./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
