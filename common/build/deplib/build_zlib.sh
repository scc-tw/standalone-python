#!/bin/sh

# This zlib is aimed to be used in the alpine, building for python run time
# dynamic linking libz.so and libz.so.1 are required.

set -e
export ZLIB_VERSION=${ZLIB_VERSION:-1.3.1}

wget https://www.zlib.net/fossils/zlib-${ZLIB_VERSION}.tar.gz
tar -xzf zlib-${ZLIB_VERSION}.tar.gz && cd zlib-${ZLIB_VERSION}

./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
