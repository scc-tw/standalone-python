#!/bin/sh

# libzstd from facebook/zstd. Required by Python 3.14+'s stdlib `_zstd`
# module (PEP 784, optional but pip will skip prebuilt zstd wheels in
# favor of stdlib if it's present). Older Python lines (3.10–3.13) don't
# use the system library — they pull in third-party `zstandard` from
# PyPI, which bundles its own copy.
#
# We build only the library (no zstd CLI, no fuzzers) and install into
# /opt/shared_libraries. rpath-patcher.sh picks up libzstd.so.1 from
# there for the shipped tree.

set -e
export ZSTD_VERSION=${ZSTD_VERSION:-1.5.6}

wget https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz
tar -xzf zstd-${ZSTD_VERSION}.tar.gz && cd zstd-${ZSTD_VERSION}

make -C lib -j $(nproc) PREFIX=/opt/shared_libraries
make -C lib install PREFIX=/opt/shared_libraries
