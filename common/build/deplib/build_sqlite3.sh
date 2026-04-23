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

# SQLite's autoconf amalgamation does NOT enable the common optional
# features by default. Python's test_sqlite3 (and many real users) expect
# FTS4/FTS5, RTREE, JSON1, column metadata, and the DBSTAT virtual table
# to be present. These flags match what Alpine, Debian, and Fedora all
# ship as their standard sqlite build.
SQLITE_FEATURE_CFLAGS=" \
    -DSQLITE_ENABLE_FTS3 \
    -DSQLITE_ENABLE_FTS3_PARENTHESIS \
    -DSQLITE_ENABLE_FTS4 \
    -DSQLITE_ENABLE_FTS5 \
    -DSQLITE_ENABLE_RTREE \
    -DSQLITE_ENABLE_JSON1 \
    -DSQLITE_ENABLE_COLUMN_METADATA \
    -DSQLITE_ENABLE_DBSTAT_VTAB \
    -DSQLITE_ENABLE_MATH_FUNCTIONS \
    -DSQLITE_ENABLE_LOAD_EXTENSION"

export CFLAGS="${CFLAGS} ${LOCAL_INCLUDES} ${SQLITE_FEATURE_CFLAGS}"
export LDFLAGS="${LDFLAGS} -L/opt/shared_libraries/lib"

./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
