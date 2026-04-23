#!/bin/sh

# This zlib is aimed to be used in the alpine, building for python run time
# dynamic linking libz.so and libz.so.1 are required.

set -e
. ./_fetch.sh

export ZLIB_VERSION=${ZLIB_VERSION:-1.3.1}
tarball="zlib-${ZLIB_VERSION}.tar.gz"

# GitHub releases is canonical; zlib.net keeps previous releases under
# /fossils/. zlib.net's root path only hosts the *current* release.
fetch_mirrored "$tarball" \
    "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/${tarball}" \
    "https://www.zlib.net/fossils/${tarball}"

tar -xzf "$tarball" && cd "zlib-${ZLIB_VERSION}"

./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
