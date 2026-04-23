#!/bin/sh

set -e
. ./_fetch.sh

export SQLITE_VERSION_LITERIAL=${SQLITE_VERSION_LITERIAL:-3.43.1}
export SQLITE_VERSION=${SQLITE_VERSION:-3430100}
export SQLITE_YEAR=${SQLITE_YEAR:-2023}
tarball="sqlite-autoconf-${SQLITE_VERSION}.tar.gz"

# Primary sqlite.org; fossies preserves every historical release as a
# year-independent URL. Verified 2026-04-23.
fetch_mirrored "$tarball" \
    "https://www.sqlite.org/${SQLITE_YEAR}/${tarball}" \
    "https://fossies.org/linux/misc/${tarball}"

tar -zxvf "$tarball" && cd "sqlite-autoconf-${SQLITE_VERSION}"

export LOCAL_INCLUDES="-I/opt/shared_libraries/include/ncurses"
export LOCAL_INCLUDES="${LOCAL_INCLUDES} -I/opt/shared_libraries/include/" # some wired packages include ncurses.h or ncurses/ncurses.h

export CFLAGS="${CFLAGS} ${LOCAL_INCLUDES}"
export LDFLAGS="${LDFLAGS} -L/opt/shared_libraries/lib"

./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
