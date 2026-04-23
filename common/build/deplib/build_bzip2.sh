#!/bin/sh

set -e
export BZIP2_VERSION=1.0.8

wget https://sourceware.org/pub/bzip2/bzip2-${BZIP2_VERSION}.tar.gz
tar -xzf bzip2-${BZIP2_VERSION}.tar.gz && cd bzip2-${BZIP2_VERSION}

# The bz2 has hard-coded gcc, and ar in the Makefile
# We delete the hard-coded gcc and use the CC variable instead.
sed -i 's/CC=gcc/CC?=gcc/g' Makefile
sed -i 's/ar=ar/ar?=ar/g' Makefile
# The CFLAGS sould take effect in the Makefile
sed -i 's/CFLAGS=\(.*\)/CFLAGS+=\1/g' Makefile

export CFLAGS="${CFLAGS} -fPIC"
make -j $(nproc)
make install PREFIX=/opt/shared_libraries
