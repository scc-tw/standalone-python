#!/bin/sh

set -e
export OPENSSL_VERSION_LITERIAL=3.43.1
export OPENSSL_VERSION=3430100

# Get https://www.sqlite.org/2023/sqlite-autoconf-3430100.tar.gz
wget https://www.sqlite.org/2023/sqlite-autoconf-${OPENSSL_VERSION}.tar.gz
tar -zxvf sqlite-autoconf-${OPENSSL_VERSION}.tar.gz && cd sqlite-autoconf-${OPENSSL_VERSION}

export LOCAL_INCLUDES="-I/opt/shared_libraries/include/ncurses"
export LOCAL_INCLUDES="${LOCAL_INCLUDES} -I/opt/shared_libraries/include/" # some wired packages include ncurses.h or ncurses/ncurses.h

export CFLAGS="${CFLAGS} ${LOCAL_INCLUDES}"
export LDFLAGS="${LDFLAGS} -L/opt/shared_libraries/lib"

./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
