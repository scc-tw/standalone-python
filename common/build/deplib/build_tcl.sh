#!/bin/sh

set -e
. ./_fetch.sh

export TCL_VERSION=${TCL_VERSION:-8.6.13}
tarball="tcl${TCL_VERSION}-src.tar.gz"

# Mirror chain verified 2026-04-23. The `prdownloads.sourceforge.net`
# redirector is kept as a last-resort — known-flaky but still present.
fetch_mirrored "$tarball" \
    "https://downloads.sourceforge.net/tcl/${tarball}" \
    "https://downloads.sourceforge.net/project/tcl/Tcl/${TCL_VERSION}/${tarball}" \
    "http://prdownloads.sourceforge.net/tcl/${tarball}"

tar -xzf "$tarball" && cd "tcl${TCL_VERSION}/unix"

./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
