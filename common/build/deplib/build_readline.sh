#!/bin/sh

# https://core.ring.gr.jp/pub/GNU/readline/readline-8.2.tar.gz
set -e
export READLINE_VERSION=8.2

wget http://core.ring.gr.jp/pub/GNU/readline/readline-${READLINE_VERSION}.tar.gz
tar -xzf readline-${READLINE_VERSION}.tar.gz && cd readline-${READLINE_VERSION}

# Patch the ltinfo not found error
# https://stackoverflow.com/a/65623630
patch --ignore-whitespace -p0 < ../fix-ncurses-underlinking.patch

export LOCAL_INCLUDES="-I/opt/shared_libraries/include/ncurses"
export LOCAL_INCLUDES="${LOCAL_INCLUDES} -I/opt/shared_libraries/include/" # some wired packages include ncurses.h or ncurses/ncurses.h

export CFLAGS="${CFLAGS} -fPIC -std=gnu11 ${LOCAL_INCLUDES}"
export LDFLAGS="${LDFLAGS} -L/opt/shared_libraries/lib"
./configure --prefix=/opt/shared_libraries --enable-static --enable-shared
make -j $(nproc) && make install 
