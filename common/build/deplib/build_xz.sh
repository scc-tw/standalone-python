#!/bin/sh

set -e
. ./_fetch.sh

export XZ_VERSION=${XZ_VERSION:-5.4.4}
tarball="xz-${XZ_VERSION}.tar.gz"

# GitHub release is primary (post-2024 supply-chain incident, GitHub is
# the more reliable source); tukaani.org backup. Verified 2026-04-23.
fetch_mirrored "$tarball" \
    "https://github.com/tukaani-project/xz/releases/download/v${XZ_VERSION}/${tarball}" \
    "https://tukaani.org/xz/${tarball}"

tar -xzf "$tarball" && cd "xz-${XZ_VERSION}"

./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
