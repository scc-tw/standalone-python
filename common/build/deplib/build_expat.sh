#!/bin/sh

# https://github.com/libexpat/libexpat/releases/download/R_2_6_0/expat-2.6.0.tar.gz
# Please upgrade bundled Expat to 2.6.0 (e.g. for the fix to CVE-2023-52425)
# https://github.com/python/cpython/issues/115399
set -e
export EXPAT_VERSION=2.6.0
export EXPAT_LITERIAL_VERSION=2_6_0

wget https://github.com/libexpat/libexpat/releases/download/R_${EXPAT_LITERIAL_VERSION}/expat-${EXPAT_VERSION}.tar.gz

tar -xzf expat-${EXPAT_VERSION}.tar.gz && cd expat-${EXPAT_VERSION}
./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
