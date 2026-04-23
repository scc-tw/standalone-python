#!/bin/sh

set -e
export NCURSES_VERSION=6.4

wget http://core.ring.gr.jp/pub/GNU/ncurses/ncurses-${NCURSES_VERSION}.tar.gz
tar -xzf ncurses-${NCURSES_VERSION}.tar.gz && cd ncurses-${NCURSES_VERSION}

export CFLAGS="${CFLAGS} -fPIC -std=gnu11"
./configure --prefix=/opt/shared_libraries \
    --with-termlib=tinfo --with-shared --without-ada --disable-termcap \
    --enable-pc-files --disable-stripping --with-cxx-binding
make -j $(nproc) && make install 
