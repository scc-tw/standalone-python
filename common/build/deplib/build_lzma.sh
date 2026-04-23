#!/bin/sh

set -e
. ./_fetch.sh

export LZMA_VERSION=${LZMA_VERSION:-4.32.7}
tarball="lzma-${LZMA_VERSION}.tar.gz"

# Classic lzma 4.x is legacy — tukaani.org is primary; the Fedora
# lookaside cache preserves the exact file keyed by its upstream MD5.
# Wayback is last-resort. All three verified live 2026-04-23.
fetch_mirrored "$tarball" \
    "https://tukaani.org/lzma/${tarball}" \
    "https://src.fedoraproject.org/lookaside/pkgs/lzma/${tarball}/2a748b77a2f8c3cbc322dbd0b4c9d06a/${tarball}" \
    "https://web.archive.org/web/2024/https://tukaani.org/lzma/${tarball}"

tar -xzf "$tarball" && cd "lzma-${LZMA_VERSION}"

export CFLAGS="${CFLAGS} -fPIC"
./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
