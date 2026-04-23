#!/bin/sh
#
# Tk build. Pairs with build_tcl.sh — Tcl and Tk are released together
# from the same SourceForge bundle, sharing a single version string.
# Python's `_tkinter` C extension links against BOTH libtcl8.6.so and
# libtk8.6.so, so without this stage `import tkinter` fails at dlopen
# time with "libtk8.6.so: No such file or directory".
#
# Tk additionally links against X11 (libX11, libXft, libXrender, libxcb,
# libfontconfig, libfreetype, …). Those come from the Alpine base_builder
# via `apk add tk-dev`, which installs the musl-built Alpine copies under
# /usr/lib. Because they're musl-built, they're ABI-compatible with the
# rest of our shipped tree (no __printf_chk / glibc-fortify mismatch that
# Debian's glibc-built X11 would hit). We copy them into
# /opt/shared_libraries/lib so libtk.so's $ORIGIN-relative rpath resolves
# them on any host — Alpine, Debian, Fedora, RHEL, wherever the final
# tarball gets extracted — with no host X11 install required.

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

# Vendor the X11 / font runtime deps libtk.so links against. These are
# Alpine's musl-built copies present in this stage courtesy of
# `apk add tk-dev` upstream in base_builder; copying them here puts them
# inside libtk.so's $ORIGIN-relative rpath so Tkinter loads without any
# host X11 installed. Names below match what Tk's final link line uses
# (see `gcc … -lXft -lfontconfig -lfreetype -lX11 …`) plus their
# transitive loader deps (libXrender, libxcb, libXau, libXdmcp).
#
# We `cp -a` each so SONAME symlinks (libfoo.so.MAJOR) *and* their
# target versioned files both land. The SONAME is what DT_NEEDED entries
# reference; the versioned file is what the symlink resolves to at load.
#
# -----------------------------------------------------------------------
# KNOWN LIMITATION / TODO — X11 is NOT built from source (yet)
# -----------------------------------------------------------------------
# This `cp -a`-from-Alpine approach is a pragmatic deviation from the
# project's "build everything from source with musl" principle. It keeps
# the CI smoke test (`ci/smoke_tkinter.py` — headless, no display, no
# drawing) green, but falls short for real GUI use:
#
#   * No `/etc/fonts/fonts.conf` and no font files are shipped.
#     fontconfig will warn and "no fonts available" surfaces the moment
#     Tk tries to render text. On a Debian-slim final image with no host
#     fontconfig package, a real `Tk()` window cannot draw labels.
#   * No `/usr/share/X11/locale/` is shipped → XmbLookupString / i18n
#     input paths degrade to C locale fallback.
#   * Transitive ELF deps beyond the 8 names below may not all be
#     captured (e.g. libpng → freetype; expat SONAME alignment with the
#     Alpine-built fontconfig vs our own build_expat.sh output).
#
# The proper fix is to add build scripts for the full stack:
#   libXau, libXdmcp, xcb-proto (py), libxcb, xtrans, xorgproto, libX11,
#   libXrender, libXext, libpng, libfreetype, libfontconfig, libXft
# plus ship a minimal `/opt/shared_libraries/etc/fonts/fonts.conf`
# and a small font set (e.g. DejaVu subset), and set FONTCONFIG_PATH /
# FONTCONFIG_FILE in launcher.c. Estimated ~10 scripts + ~1–2 days.
# Tracked informally here until promoted to a real issue.
# -----------------------------------------------------------------------
for name in X11 Xft Xrender Xau Xdmcp xcb fontconfig freetype; do
    found=0
    for f in /usr/lib/lib${name}.so* /lib/lib${name}.so*; do
        if [ -e "$f" ]; then
            cp -a "$f" /opt/shared_libraries/lib/
            found=1
        fi
    done
    if [ "$found" -eq 0 ]; then
        echo "warning: no lib${name}.so* found in /usr/lib or /lib" >&2
    fi
done
