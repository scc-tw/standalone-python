#!/bin/sh

# libuuid out of the util-linux source tree. Used by Python's _uuid C
# extension (faster path; gives uuid_generate_time_safe). Without it,
# `import uuid` still works via ctypes/pure-Python fallbacks but loses
# performance and the safe-MAC API.
#
# We build only the libuuid library (not any util-linux programs) and
# install into /opt/shared_libraries so the existing rpath-patcher pass
# resolves it $ORIGIN-relative inside the shipped tree.

set -e
. ./_fetch.sh

export UUID_VERSION=${UUID_VERSION:-2.40.4}
UUID_BRANCH=${UUID_VERSION%.*}
tarball="util-linux-${UUID_VERSION}.tar.xz"

# kernel.org primary; mirrors.edge.kernel.org is the CDN-fronted mirror
# with identical layout. The GitHub tag archive uses a different top-dir
# and ships no pre-built configure, so it's not a drop-in substitute.
# Verified 2026-04-23.
fetch_mirrored "$tarball" \
    "https://www.kernel.org/pub/linux/utils/util-linux/v${UUID_BRANCH}/${tarball}" \
    "https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v${UUID_BRANCH}/${tarball}"

tar -xJf "$tarball" && cd "util-linux-${UUID_VERSION}"

./configure --prefix=/opt/shared_libraries \
    --disable-all-programs --enable-libuuid \
    --without-systemd --without-python --without-ncurses \
    --disable-bash-completion --disable-makeinstall-chown --disable-makeinstall-setuid
make -j $(nproc) && make install
