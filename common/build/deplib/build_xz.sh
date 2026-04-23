#!/bin/sh

set -e
export XZ_VERSION=5.4.4

wget https://tukaani.org/xz/xz-${XZ_VERSION}.tar.gz
tar -xzf xz-${XZ_VERSION}.tar.gz && cd xz-${XZ_VERSION}

./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
