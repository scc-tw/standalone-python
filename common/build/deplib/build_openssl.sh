#!/bin/sh

set -e
. ./_fetch.sh

# Allow overriding OpenSSL version via environment
export OPENSSL_VERSION=${OPENSSL_VERSION:-1.1.1w}
tarball="openssl-${OPENSSL_VERSION}.tar.gz"

# Primary openssl.org; GitHub release as same-layout backup (OpenSSL
# mirrors every release on github.com/openssl/openssl/releases).
# Verified 2026-04-23.
fetch_mirrored "$tarball" \
    "https://www.openssl.org/source/${tarball}" \
    "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/${tarball}"

tar -xvf "$tarball" && cd "openssl-${OPENSSL_VERSION}"

# Architecture-aware configuration.
# --libdir=lib pins the install path for OpenSSL 3.x, which otherwise picks lib64 on x86_64.
if [ "$IS_32BIT" = "1" ]; then
    # 32-bit configuration
    ./Configure linux-generic32 --shared --prefix=/opt/shared_libraries --libdir=lib
else
    # 64-bit configuration (default)
    ./config --prefix=/opt/shared_libraries --libdir=lib
fi

make -j $(nproc) && make install
