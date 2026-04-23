#!/bin/sh
#
# Tk build. Pairs with build_tcl.sh — Tcl and Tk are released together
# from the same SourceForge bundle, sharing a single version string.
# Python's `_tkinter` C extension links against BOTH libtcl8.6.so and
# libtk8.6.so, so without this stage `import tkinter` fails at dlopen
# time with "libtk8.6.so: No such file or directory".
#
# Tk itself links against X11 (libX11, libXft, libfontconfig, …). Those
# are *host*-provided at runtime — we don't bundle X11 since it's large
# and every desktop Linux system ships them natively. On a pure server
# image without X11 libs installed, `import tkinter` will still fail
# (libX11.so.6 missing). Callers who need headless Tk can apt-install
# `libx11-6 libxft2 libfontconfig1` or use `xvfb-run`.

set -e
. ./_fetch.sh

export TCL_VERSION=${TCL_VERSION:-8.6.13}
tarball="tk${TCL_VERSION}-src.tar.gz"

# Same SourceForge chain as tcl — all three URLs verified serving the
# real tarball (gzip magic bytes confirmed) on 2026-04-23.
fetch_mirrored "$tarball" \
    "https://downloads.sourceforge.net/tcl/${tarball}" \
    "https://downloads.sourceforge.net/project/tcl/Tcl/${TCL_VERSION}/${tarball}" \
    "http://prdownloads.sourceforge.net/tcl/${tarball}"

tar -xzf "$tarball" && cd "tk${TCL_VERSION}/unix"

# --with-tcl points at the shipped Tcl's tclConfig.sh (dropped into
# /opt/shared_libraries/lib by tcl_builder). Without this flag Tk's
# configure picks up whatever tclConfig.sh is on the host's default
# path, which on Alpine is /usr/lib and gives wrong linker hints.
./configure --prefix=/opt/shared_libraries --with-tcl=/opt/shared_libraries/lib
make -j $(nproc) && make install
