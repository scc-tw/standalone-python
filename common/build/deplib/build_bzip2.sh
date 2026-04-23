#!/bin/sh

set -e
. ./_fetch.sh

export BZIP2_VERSION=${BZIP2_VERSION:-1.0.8}
tarball="bzip2-${BZIP2_VERSION}.tar.gz"

# sourceware.org is canonical since bzip.org was retired; fossies preserves
# the exact released tarball with the expected top-dir layout. The GitLab
# repo-archive tarball uses `bzip2-bzip2-${V}/` as its top directory, so
# it's not a drop-in substitute and we don't use it. Verified 2026-04-23.
fetch_mirrored "$tarball" \
    "https://sourceware.org/pub/bzip2/${tarball}" \
    "https://fossies.org/linux/misc/${tarball}"

tar -xzf "$tarball" && cd "bzip2-${BZIP2_VERSION}"

# The bz2 has hard-coded gcc, and ar in the Makefile
# We delete the hard-coded gcc and use the CC variable instead.
sed -i 's/CC=gcc/CC?=gcc/g' Makefile
sed -i 's/ar=ar/ar?=ar/g' Makefile
# The CFLAGS sould take effect in the Makefile
sed -i 's/CFLAGS=\(.*\)/CFLAGS+=\1/g' Makefile

export CFLAGS="${CFLAGS} -fPIC"
make -j $(nproc)
make install PREFIX=/opt/shared_libraries
