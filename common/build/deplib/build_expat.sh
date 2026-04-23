#!/bin/sh

# Please upgrade bundled Expat to 2.6.0+ (fix for CVE-2023-52425):
# https://github.com/python/cpython/issues/115399
set -e
. ./_fetch.sh

export EXPAT_VERSION=${EXPAT_VERSION:-2.6.0}
export EXPAT_LITERIAL_VERSION=${EXPAT_LITERIAL_VERSION:-$(echo "$EXPAT_VERSION" | tr . _)}
tarball="expat-${EXPAT_VERSION}.tar.gz"

# GitHub releases is the canonical source since expat moved off
# SourceForge (SF project page is empty as of 2026-04). Retry+backoff
# via _fetch.sh covers transient GH hiccups.
fetch_mirrored "$tarball" \
    "https://github.com/libexpat/libexpat/releases/download/R_${EXPAT_LITERIAL_VERSION}/${tarball}"

tar -xzf "$tarball" && cd "expat-${EXPAT_VERSION}"
./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
