#!/bin/sh

set -e
export FFI_VERSION=3.4.4

wget https://github.com/libffi/libffi/releases/download/v${FFI_VERSION}/libffi-${FFI_VERSION}.tar.gz
tar -xvf libffi-${FFI_VERSION}.tar.gz && cd libffi-${FFI_VERSION}

export CFLAGS="${CFLAGS} -fPIC"
./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
