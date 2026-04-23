FROM --platform=linux/386 alpine:3.22 AS base_builder

ENV PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    LANG=C.UTF-8 \
    PYTHON_VERSION=3.11.15 \
    IS_32BIT=1 \
    ZLIB_VERSION=1.3.2 \
    FFI_VERSION=3.5.2 \
    EXPAT_VERSION=2.7.5 \
    GDBM_VERSION=1.26 \
    LZMA_VERSION=4.32.7 \
    GETTEXT_VERSION=1.0 \
    NCURSES_VERSION=6.6 \
    OPENSSL_VERSION=3.5.6 \
    READLINE_VERSION=8.3 \
    TCL_VERSION=8.6.17 \
    XZ_VERSION=5.8.3 \
    BZIP2_VERSION=1.0.8 \
    UUID_VERSION=2.40.4 \
    SQLITE_VERSION=3530000 \
    SQLITE_VERSION_LITERIAL=3.53.0 \
    SQLITE_YEAR=2026 \
    PYTHON_PIP_VERSION=26.0.1 \
    PYTHON_SETUPTOOLS_VERSION=82.0.1

WORKDIR /src
RUN set -eux && apk add --no-cache ca-certificates tzdata && \
    apk add --no-cache --virtual .build-deps tar xz bluez-dev dpkg-dev dpkg findutils gcc file g++ \
        libc-dev libnsl-dev libtirpc-dev linux-headers make pax-utils tk tk-dev util-linux-dev wget \
        bison flex gawk patch

# # =========== musl ===========
FROM --platform=linux/386 debian:bookworm AS musl_builder
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Taipei \
    IS_32BIT=1

RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y build-essential wget git file tar xz-utils dpkg-dev libnsl-dev libtirpc-dev uuid-dev patch

WORKDIR /src
COPY ["common/build/deplib/build_musl.sh", "3.11/x86/deplib/config.mak", "."]
RUN set -eux && ./build_musl.sh

# =========== libz ===========
FROM base_builder AS libz_builder
COPY ["common/build/deplib/build_zlib.sh", "."]
RUN set -eux && ./build_zlib.sh

# =========== ffi ===========
FROM libz_builder AS ffi_builder
COPY ["common/build/deplib/build_ffi.sh", "."]
RUN set -eux && ./build_ffi.sh

# =========== expat ===========
FROM ffi_builder AS expat_builder
COPY ["common/build/deplib/build_expat.sh", "."]
RUN set -eux && ./build_expat.sh

# =========== gdbm ===========
FROM expat_builder AS gdbm_builder
COPY ["common/build/deplib/build_gdbm.sh", "."]
RUN set -eux && ./build_gdbm.sh

# =========== lzma ===========
FROM gdbm_builder AS lzma_builder
COPY ["common/build/deplib/build_lzma.sh", "."]
RUN set -eux && ./build_lzma.sh

# =========== gettext ===========
FROM lzma_builder AS gettext_builder
COPY ["common/build/deplib/build_gettext.sh", "."]
RUN set -eux && ./build_gettext.sh

# =========== ncurses ===========
FROM gettext_builder AS ncurses_builder
COPY ["common/build/deplib/build_ncurses.sh", "."]
RUN set -eux && ./build_ncurses.sh

# =========== openssl ===========
FROM ncurses_builder AS openssl_builder
COPY ["common/build/deplib/build_openssl.sh", "."]
RUN set -eux && ./build_openssl.sh

# =========== readline ===========
FROM openssl_builder AS readline_builder
COPY ["common/build/deplib/build_readline.sh", "common/patches/common/ncurses/fix-ncurses-underlinking.patch", "."]
RUN set -eux && ./build_readline.sh

# =========== tcl ===========
FROM readline_builder AS tcl_builder
COPY ["common/build/deplib/build_tcl.sh", "."]
RUN set -eux && ./build_tcl.sh

# =========== xz ===========
FROM tcl_builder AS xz_builder
COPY ["common/build/deplib/build_xz.sh", "."]
RUN set -eux && ./build_xz.sh

# =========== bzip2 ===========
FROM xz_builder AS bzip2_builder
COPY ["common/build/deplib/build_bzip2.sh", "."]
RUN set -eux && ./build_bzip2.sh

# =========== uuid ===========
FROM bzip2_builder AS uuid_builder
COPY ["common/build/deplib/build_uuid.sh", "."]
RUN set -eux && ./build_uuid.sh

# =========== sqlite3 ===========
FROM uuid_builder AS sqlite3_builder
COPY ["common/build/deplib/build_sqlite3.sh", "."]
RUN set -eux && ./build_sqlite3.sh

# =========== Python ===========
FROM sqlite3_builder AS python_builder

COPY ["common/build/deplib/build_python.sh", "common/build/deplib/install_pip.sh", "."]
RUN set -eux && ./build_python.sh && ./install_pip.sh

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
RUN install -m 0755 /tmp/launcher /opt/python/bin/python3 && \
    install -m 0755 /tmp/launcher /opt/python/bin/pip3 && \
    rm /tmp/launcher && \
    cd /opt/python/bin && \
    ln -sf python3 python && \
    ln -sf pip3 pip

# Copy shipped musl runtime and rewrite RPATH on Python's bundled ELFs so
# $ORIGIN-relative lookups resolve inside the installed tree. No .interp
# patching is needed — the static launcher invokes ld-musl.so directly.
COPY --from=musl_builder /opt/musl /opt/musl
COPY ["common/build/wrappers/rpath-patcher.sh", "."]
RUN set -eux && ./rpath-patcher.sh

# Site-level hook that tells pip/packaging the shipped libc is musl so wheel
# resolution picks `musllinux_*` wheels instead of glibc-built manylinux
# wheels. Runs on every Python startup via the .pth but is a no-op unless
# the launcher has set _STANDALONE_PYTHON_MUSL_VERSION in the env.
COPY ["common/build/wrappers/standalone_python_musl.py", \
      "common/build/wrappers/standalone_python_musl.pth", \
      "/opt/python/lib/python3.11/site-packages/"]

# =========== final ===========
FROM --platform=linux/386 debian:latest AS final
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Taipei

COPY --from=patch_stage /opt/python /opt/python
