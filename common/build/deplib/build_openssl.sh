#!/bin/sh

set -e

# Allow overriding OpenSSL version via environment
export OPENSSL_VERSION=${OPENSSL_VERSION:-1.1.1w}

wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
tar -xvf openssl-${OPENSSL_VERSION}.tar.gz && cd openssl-${OPENSSL_VERSION}

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
