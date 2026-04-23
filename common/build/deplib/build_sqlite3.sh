#!/bin/sh

set -e
export SQLITE_VERSION_LITERIAL=${SQLITE_VERSION_LITERIAL:-3.43.1}
export SQLITE_VERSION=${SQLITE_VERSION:-3430100}
export SQLITE_YEAR=${SQLITE_YEAR:-2023}

# Get https://www.sqlite.org/2023/sqlite-autoconf-3430100.tar.gz
wget https://www.sqlite.org/${SQLITE_YEAR}/sqlite-autoconf-${SQLITE_VERSION}.tar.gz
tar -zxvf sqlite-autoconf-${SQLITE_VERSION}.tar.gz && cd sqlite-autoconf-${SQLITE_VERSION}

export LOCAL_INCLUDES="-I/opt/shared_libraries/include/ncurses"
export LOCAL_INCLUDES="${LOCAL_INCLUDES} -I/opt/shared_libraries/include/" # some wired packages include ncurses.h or ncurses/ncurses.h

export CFLAGS="${CFLAGS} ${LOCAL_INCLUDES}"
export LDFLAGS="${LDFLAGS} -L/opt/shared_libraries/lib"

./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
