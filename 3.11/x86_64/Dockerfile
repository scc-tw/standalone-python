ARG TARGETPLATFORM=linux/amd64
FROM --platform=${TARGETPLATFORM} alpine:3.18.3 AS base_builder

ENV PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    LANG=C.UTF-8 \
    PYTHON_VERSION=3.11.9 \
    IS_32BIT=0 \
    ZLIB_VERSION=1.3.1 \
    FFI_VERSION=3.4.4 \
    EXPAT_VERSION=2.6.0 \
    GDBM_VERSION=1.23 \
    LZMA_VERSION=4.32.7 \
    GETTEXT_VERSION=0.22.2 \
    NCURSES_VERSION=6.4 \
    OPENSSL_VERSION=1.1.1w \
    READLINE_VERSION=8.2 \
    TCL_VERSION=8.6.13 \
    XZ_VERSION=5.4.4 \
    BZIP2_VERSION=1.0.8 \
    SQLITE_VERSION=3430100 \
    SQLITE_VERSION_LITERIAL=3.43.1 \
    SQLITE_YEAR=2023 \
    PYTHON_PIP_VERSION=23.2.1 \
    PYTHON_SETUPTOOLS_VERSION=65.5.1

WORKDIR /src
RUN set -eux && apk add --no-cache ca-certificates tzdata && \
    apk add --no-cache --virtual .build-deps tar xz bluez-dev dpkg-dev dpkg findutils gcc file g++ \
        libc-dev libnsl-dev libtirpc-dev linux-headers make pax-utils tk tk-dev util-linux-dev wget \
        bison flex gawk patch

# # =========== musl ===========
FROM --platform=${TARGETPLATFORM} debian:bookworm AS musl_builder
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Taipei \
    IS_32BIT=0

RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y build-essential wget git file tar xz-utils dpkg-dev libnsl-dev libtirpc-dev uuid-dev patch

WORKDIR /src
COPY ["common/build/deplib/build_musl.sh", "3.11/x86_64/deplib/config.mak", "."]
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

# =========== sqlite3 ===========
FROM bzip2_builder AS sqlite3_builder
COPY ["common/build/deplib/build_sqlite3.sh", "."]
RUN set -eux && ./build_sqlite3.sh

# =========== Python ===========
FROM sqlite3_builder AS python_builder

COPY ["common/build/deplib/build_python.sh", "common/build/deplib/install_pip.sh", "."]
RUN set -eux && ./build_python.sh && ./install_pip.sh

# =========== patch_stage ===========
FROM --platform=${TARGETPLATFORM} debian:latest AS patch_stage
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Taipei \
    IS_32BIT=0

RUN apt-get update -y && apt-get install -y patchelf file

COPY --from=python_builder /opt/shared_libraries /opt/shared_libraries
COPY --from=python_builder /opt/python /opt/python

COPY ["common/build/wrappers/packing-initializer", "common/build/wrappers/python-wrapper", "common/build/wrappers/pip-wrapper", "."]
RUN ./packing-initializer && rm -rf packing-initializer && \
    mv python-wrapper /opt/python/bin/python3 && \
    mv pip-wrapper /opt/python/bin/pip3 && \
    cd  /opt/python/bin && \
    ln -sf python3 python && \
    ln -sf pip3 pip

# Patch the generated python and related dynamic libraries
COPY --from=musl_builder /opt/musl /opt/musl
COPY ["common/build/wrappers/interpreter-patcher.sh", "."]
RUN set -eux && ./interpreter-patcher.sh

# =========== final ===========
FROM --platform=${TARGETPLATFORM} debian:latest AS final
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Taipei

COPY --from=patch_stage /opt/python /opt/python
