#!/bin/sh

set -e
. ./_fetch.sh

export NCURSES_VERSION=${NCURSES_VERSION:-6.4}
tarball="ncurses-${NCURSES_VERSION}.tar.gz"

# Primary is upstream maintainer (invisible-island.net); ftp.gnu.org is
# canonical; core.ring.gr.jp kept as last-resort only (has had flaky DNS
# on GitHub CI). Verified 2026-04-23.
fetch_mirrored "$tarball" \
    "https://invisible-island.net/archives/ncurses/${tarball}" \
    "https://ftp.gnu.org/gnu/ncurses/${tarball}" \
    "https://mirrors.kernel.org/gnu/ncurses/${tarball}" \
    "http://core.ring.gr.jp/pub/GNU/ncurses/${tarball}"

tar -xzf "$tarball" && cd "ncurses-${NCURSES_VERSION}"

export CFLAGS="${CFLAGS} -fPIC -std=gnu11"
./configure --prefix=/opt/shared_libraries \
    --with-termlib=tinfo --with-shared --without-ada --disable-termcap \
    --enable-pc-files --disable-stripping --with-cxx-binding
make -j $(nproc) && make install
