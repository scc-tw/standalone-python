#!/bin/sh

set -e
. ./_fetch.sh

export GETTEXT_VERSION=${GETTEXT_VERSION:-0.22.2}
tarball="gettext-${GETTEXT_VERSION}.tar.gz"

# GNU mirror chain. ftpmirror.gnu.org already does geographic-redirect,
# the rest are stable independent mirrors. Verified 2026-04-23.
fetch_mirrored "$tarball" \
    "https://ftpmirror.gnu.org/gettext/${tarball}" \
    "https://ftp.gnu.org/gnu/gettext/${tarball}" \
    "https://mirrors.kernel.org/gnu/gettext/${tarball}" \
    "https://ftp.osuosl.org/pub/gnu/gettext/${tarball}"

tar -xzf "$tarball" && cd "gettext-${GETTEXT_VERSION}"

export CFLAGS="${CFLAGS} -fPIC"
./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
