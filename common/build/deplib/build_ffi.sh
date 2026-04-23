#!/bin/sh

set -e
. ./_fetch.sh

export FFI_VERSION=${FFI_VERSION:-3.4.4}
tarball="libffi-${FFI_VERSION}.tar.gz"

# GitHub is the canonical home for libffi 3.4+; sourceware stopped
# mirroring new releases. Retry+backoff via _fetch.sh covers transient
# GH hiccups.
fetch_mirrored "$tarball" \
    "https://github.com/libffi/libffi/releases/download/v${FFI_VERSION}/${tarball}"

tar -xvf "$tarball" && cd "libffi-${FFI_VERSION}"

export CFLAGS="${CFLAGS} -fPIC"
./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
