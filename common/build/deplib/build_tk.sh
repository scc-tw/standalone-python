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
# project's "build everything from source with musl" principle. The
# tkinter CI smoke (`ci/smoke_tkinter.py`) is intentionally marked
# non-blocking (continue-on-error in .github/workflows/build.yml,
# `|| echo` in .gitlab-ci.yml) so the rest of the build pipeline keeps
# reporting useful signal while the full X11 stack remains unfinished.
#
# --- Confirmed failures observed on Debian-slim final image ---
# 1. `import _tkinter` → ImportError: libbz2.so.1 not found, needed by
#    our copied libfreetype.so.6.
#    Root cause: build_bzip2.sh only produces static libbz2.a; no
#    libbz2.so* is ever installed into /opt/shared_libraries/lib/.
#    Alpine's libfreetype has DT_NEEDED=libbz2.so.1 → dlopen fails.
#
# --- Predicted follow-on failures (not yet hit because we fail fast
#     on #1, but will surface once #1 is fixed) ---
# 2. libfreetype.so.6 also has DT_NEEDED=libpng.so.16; we build no
#    libpng at all. Needs a new build_libpng.sh.
# 3. libfontconfig.so.1 needs libexpat.so.1 at a specific SONAME.
#    We build expat (build_expat.sh) but the SONAME emitted by our
#    build may not match what Alpine's libfontconfig was linked to.
#    Needs `readelf -d` check.
# 4. Actual GUI use (`Tk()` + `Label(text=...).pack()`):
#      a. No `/etc/fonts/fonts.conf` on final image → fontconfig
#         warns and falls back; on a Debian-slim base without the
#         fontconfig package, no font is found → render errors.
#      b. No font files shipped (e.g. DejaVu sans / Noto) →
#         fontconfig has nothing to serve even with a valid config.
#      c. No `/usr/share/X11/locale/` → XmbLookupString / i18n input
#         path degrades to C locale.
#
# --- Proper fix (Option A in the design discussion) ---
# Replace this `cp -a` block with real from-source builds, in order:
#     libXau, libXdmcp, xcb-proto (python module), libxcb,
#     xtrans (headers), xorgproto (headers), libX11, libXext,
#     libXrender, libpng, libfreetype (relink against our libpng
#     + our libbz2.so.1 after build_bzip2.sh ships a shared version),
#     libfontconfig (against our expat + freetype), libXft.
# Plus:
#     - ship `/opt/shared_libraries/etc/fonts/fonts.conf`
#     - ship a minimal font subset (e.g. DejaVu sans ~1–2 MB)
#     - set FONTCONFIG_PATH / FONTCONFIG_FILE in launcher.c so
#       fontconfig finds the shipped config/fonts first
# Estimated ~10 build scripts + font/config shipping, ~1–2 days.
#
# Tracked informally here until promoted to a real GitHub issue.
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
