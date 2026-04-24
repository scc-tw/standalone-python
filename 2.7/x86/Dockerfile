FROM --platform=linux/386 alpine:3.22 AS base_builder

# Python 2.7.18 — final 2.7 release (April 2020). Deliberate version pins
# below are compatibility-driven (see docs / issue #9):
#   * OPENSSL_VERSION=1.1.1w  — 2.7's _ssl / _hashopenssl use APIs that
#     OpenSSL 3.x removed (CRYPTO_num_locks, ERR_load_*_strings,
#     FIPS_mode). 1.1.1w is the final 1.1.1 release and the newest line
#     that 2.7 compiles against cleanly, without patches.
#   * PYTHON_PIP_VERSION=20.3.4, SETUPTOOLS=44.1.1 — last versions that
#     support Python 2.
#   * xz / lzma are not shipped: 2.7 has no stdlib `_lzma` module.
#   * libffi and expat are left bundled (Modules/_ctypes/libffi,
#     Modules/expat); external versions are too new for 2.7.
ENV PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    LANG=C.UTF-8 \
    PYTHON_VERSION=2.7.18 \
    IS_32BIT=1 \
    ZLIB_VERSION=1.3.2 \
    FFI_VERSION=3.5.2 \
    EXPAT_VERSION=2.7.5 \
    GDBM_VERSION=1.26 \
    GETTEXT_VERSION=1.0 \
    NCURSES_VERSION=6.6 \
    OPENSSL_VERSION=1.1.1w \
    READLINE_VERSION=8.3 \
    TCL_VERSION=8.6.17 \
    BZIP2_VERSION=1.0.8 \
    SQLITE_VERSION=3530000 \
    SQLITE_VERSION_LITERIAL=3.53.0 \
    SQLITE_YEAR=2026 \
    PYTHON_PIP_VERSION=20.3.4 \
    PYTHON_SETUPTOOLS_VERSION=44.1.1

WORKDIR /src
RUN set -eux && apk add --no-cache ca-certificates tzdata && \
    apk add --no-cache --virtual .build-deps tar xz bluez-dev dpkg-dev dpkg findutils gcc file g++ \
        libc-dev libnsl-dev libtirpc-dev linux-headers make pax-utils tk tk-dev util-linux-dev wget \
        bison flex gawk patch

COPY ["common/build/deplib/_fetch.sh", "."]

# =========== musl ===========
FROM --platform=linux/386 debian:bookworm AS musl_builder
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Taipei \
    IS_32BIT=1

RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y build-essential wget git file tar xz-utils dpkg-dev libnsl-dev libtirpc-dev uuid-dev patch

WORKDIR /src
COPY ["common/build/deplib/build_musl.sh", "2.7/x86/deplib/config.mak", "."]
RUN set -eux && ./build_musl.sh

# =========== libz ===========
FROM base_builder AS libz_builder
COPY ["common/build/deplib/build_zlib.sh", "."]
RUN set -eux && ./build_zlib.sh

# =========== ffi ===========
# External libffi still built so third-party C extensions have a system
# libffi available; Python 2.7 itself uses its bundled copy.
FROM base_builder AS ffi_builder
COPY ["common/build/deplib/build_ffi.sh", "."]
RUN set -eux && ./build_ffi.sh

# =========== expat ===========
# Same reasoning as ffi: shipped for third-party use; Python 2.7 uses the
# bundled copy under Modules/expat.
FROM base_builder AS expat_builder
COPY ["common/build/deplib/build_expat.sh", "."]
RUN set -eux && ./build_expat.sh

# =========== gdbm ===========
FROM base_builder AS gdbm_builder
COPY ["common/build/deplib/build_gdbm.sh", "."]
RUN set -eux && ./build_gdbm.sh

# =========== gettext ===========
FROM base_builder AS gettext_builder
COPY ["common/build/deplib/build_gettext.sh", "."]
RUN set -eux && ./build_gettext.sh

# =========== ncurses ===========
FROM base_builder AS ncurses_builder
COPY ["common/build/deplib/build_ncurses.sh", "."]
RUN set -eux && ./build_ncurses.sh

# =========== openssl (1.1.1w for Python 2.7 compatibility) ===========
FROM libz_builder AS openssl_builder
COPY ["common/build/deplib/build_openssl.sh", "."]
RUN set -eux && ./build_openssl.sh

# =========== readline ===========
FROM ncurses_builder AS readline_builder
COPY ["common/build/deplib/build_readline.sh", "common/patches/common/ncurses/fix-ncurses-underlinking.patch", "."]
RUN set -eux && ./build_readline.sh

# =========== tcl ===========
FROM base_builder AS tcl_builder
COPY ["common/build/deplib/build_tcl.sh", "."]
RUN set -eux && ./build_tcl.sh

# =========== tk (GUI toolkit; _tkinter links libtk8.6.so) ===========
FROM tcl_builder AS tk_builder
COPY ["common/build/deplib/build_tk.sh", "."]
RUN set -eux && ./build_tk.sh

# =========== bzip2 ===========
FROM base_builder AS bzip2_builder
COPY ["common/build/deplib/build_bzip2.sh", "."]
RUN set -eux && ./build_bzip2.sh

# =========== sqlite3 ===========
FROM readline_builder AS sqlite3_builder
COPY ["common/build/deplib/build_sqlite3.sh", "."]
RUN set -eux && ./build_sqlite3.sh

# =========== deps_merged (fan-in from parallel dep stages) ===========
# Each deplib stage above is FROM base_builder (plus the two real
# edges: openssl<-libz, readline<-ncurses, sqlite3<-readline).
# BuildKit runs the leaves in parallel; this stage merges their
# /opt/shared_libraries outputs into one prefix for python_builder.
FROM base_builder AS deps_merged
COPY --from=libz_builder /opt/shared_libraries /opt/shared_libraries
COPY --from=ffi_builder /opt/shared_libraries /opt/shared_libraries
COPY --from=expat_builder /opt/shared_libraries /opt/shared_libraries
COPY --from=gdbm_builder /opt/shared_libraries /opt/shared_libraries
COPY --from=gettext_builder /opt/shared_libraries /opt/shared_libraries
COPY --from=ncurses_builder /opt/shared_libraries /opt/shared_libraries
COPY --from=openssl_builder /opt/shared_libraries /opt/shared_libraries
COPY --from=readline_builder /opt/shared_libraries /opt/shared_libraries
COPY --from=tcl_builder /opt/shared_libraries /opt/shared_libraries
COPY --from=tk_builder /opt/shared_libraries /opt/shared_libraries
COPY --from=bzip2_builder /opt/shared_libraries /opt/shared_libraries
COPY --from=sqlite3_builder /opt/shared_libraries /opt/shared_libraries

# =========== Python 2.7 ===========
FROM deps_merged AS python_builder

COPY ["common/build/deplib/build_python_py2.sh", "common/build/deplib/install_pip_py2.sh", "common/patches/common/python/py27-tkinter-gcc14-typecast.patch", "."]
RUN set -eux && ./build_python_py2.sh && ./install_pip_py2.sh

# =========== launcher (static C binary, replaces shell wrappers) ===========
FROM musl_builder AS launcher_builder
ENV MUSL_ARCH=i386
WORKDIR /src
COPY ["common/build/wrappers/launcher.c", "./launcher.c"]
# config.mak carries `MUSL_VER = X.Y.Z`; drop the patch component and bake
# `X.Y` into the launcher as MUSL_VERSION so the site hook can hand pip the
# matching `musllinux_X_Y_*` wheel tag without subprocess'ing ld.so every
# Python startup.
RUN set -eux && \
    MUSL_VER=$(awk -F'=' '/^MUSL_VER[[:space:]]*=/ { gsub(/[[:space:]]/, "", $2); print $2 }' /src/config.mak) && \
    MUSL_TAG=$(echo "$MUSL_VER" | cut -d. -f1,2) && \
    test -n "$MUSL_TAG" && \
    /opt/musl/bin/${MUSL_ARCH}-linux-musl-gcc -static -Os -s \
        -DMUSL_ARCH="\"${MUSL_ARCH}\"" \
        -DMUSL_VERSION="\"${MUSL_TAG}\"" \
        launcher.c -o launcher && \
    file launcher

# =========== patch_stage ===========
FROM --platform=linux/386 debian:latest AS patch_stage
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Taipei \
    IS_32BIT=1

RUN apt-get update -y && apt-get install -y patchelf file

COPY --from=python_builder /opt/shared_libraries /opt/shared_libraries
COPY --from=python_builder /opt/python /opt/python

COPY ["common/build/wrappers/packing-initializer", "."]
RUN ./packing-initializer && rm -rf packing-initializer

COPY --from=launcher_builder /src/launcher /tmp/launcher
RUN install -m 0755 /tmp/launcher /opt/python/bin/python2 && \
    install -m 0755 /tmp/launcher /opt/python/bin/pip2 && \
    rm /tmp/launcher && \
    cd /opt/python/bin && \
    ln -sf python2 python && \
    ln -sf pip2 pip

# Copy shipped musl runtime and rewrite RPATH on Python's bundled ELFs so
# $ORIGIN-relative lookups resolve inside the installed tree. No .interp
# patching is needed — the static launcher invokes ld-musl.so directly.
COPY --from=musl_builder /opt/musl /opt/musl
COPY ["common/build/wrappers/rpath-patcher.sh", "."]
RUN set -eux && ./rpath-patcher.sh

# Note: no musllinux site-hook for Python 2.7. pip 20.x's vendored
# packaging predates the clean `_musllinux` split and is rarely a
# bottleneck for pip 2.7 users (most Py2 wheels on PyPI are pure-Python
# `py2.py3-none-any`). Users needing native wheels can install with
# `--no-binary :all:`.
#
# What we DO need on 2.7 is the sysconfig prefix-sentinel expansion, so
# that a pip install from source (-> distutils/sysconfig LDFLAGS) resolves
# libffi/libsqlite3/libreadline/… against the install's actual prefix
# after packing-initializer's relocation (and after an end-user move).
COPY ["common/build/wrappers/standalone_python_musl_py2.py", \
      "common/build/wrappers/standalone_python_musl_py2.pth", \
      "/opt/python/lib/python2.7/site-packages/"]

# =========== final ===========
FROM --platform=linux/386 debian:latest AS final
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Taipei

COPY --from=patch_stage /opt/python /opt/python
