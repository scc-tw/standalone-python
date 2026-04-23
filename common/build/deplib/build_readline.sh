#!/bin/sh

set -e
. ./_fetch.sh

export READLINE_VERSION=${READLINE_VERSION:-8.2}
tarball="readline-${READLINE_VERSION}.tar.gz"

# Mirror chain verified live 2026-04-23. Retired the old core.ring.gr.jp
# primary — it has recurrent DNS dropouts on GitHub CI.
fetch_mirrored "$tarball" \
    "https://ftpmirror.gnu.org/readline/${tarball}" \
    "https://ftp.gnu.org/gnu/readline/${tarball}" \
    "https://mirrors.kernel.org/gnu/readline/${tarball}" \
    "https://ftp.osuosl.org/pub/gnu/readline/${tarball}"

tar -xzf "$tarball" && cd "readline-${READLINE_VERSION}"

# Patch the ltinfo not found error
# https://stackoverflow.com/a/65623630
patch --ignore-whitespace -p0 < ../fix-ncurses-underlinking.patch

export LOCAL_INCLUDES="-I/opt/shared_libraries/include/ncurses"
export LOCAL_INCLUDES="${LOCAL_INCLUDES} -I/opt/shared_libraries/include/" # some wired packages include ncurses.h or ncurses/ncurses.h

export CFLAGS="${CFLAGS} -fPIC -std=gnu11 ${LOCAL_INCLUDES}"
export LDFLAGS="${LDFLAGS} -L/opt/shared_libraries/lib"
./configure --prefix=/opt/shared_libraries --enable-static --enable-shared
make -j $(nproc) && make install
