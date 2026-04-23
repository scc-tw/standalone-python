#!/bin/sh

# https://ftpmirror.gnu.org/gettext/gettext-0.22.2.tar.gz
set -e
export GETTEXT_VERSION=0.22.2

wget https://ftp.gnu.org/gnu/gettext/gettext-${GETTEXT_VERSION}.tar.gz
tar -xzf gettext-${GETTEXT_VERSION}.tar.gz && cd gettext-${GETTEXT_VERSION}

export CFLAGS="${CFLAGS} -fPIC"
./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
