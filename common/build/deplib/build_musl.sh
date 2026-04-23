#!/bin/bash

set -euo pipefail

# musl-cross-make pulls binutils/gmp/mpc/mpfr/gcc tarballs through
# ftpmirror.gnu.org, which is a redirector that routes to mirrors of
# wildly varying quality. When a redirect lands on a sad mirror the
# response is HTTP 502 and the wget invocation inside their Makefile
# gives up after one try, killing the entire build. We make wget retry
# 5xx responses globally so musl-cross-make's untouched Makefile gets
# the resilience for free.
mkdir -p /etc
cat > /etc/wgetrc <<'WGETRC'
tries = 10
waitretry = 10
timeout = 60
retry_connrefused = on
retry_on_http_error = 408,429,500,502,503,504
WGETRC

git clone --depth 1 https://github.com/25077667/musl-cross-make.git

cp ./config.mak musl-cross-make/config.mak

OUTPUT_DIR="$(awk -F= '/^[[:space:]]*OUTPUT[[:space:]]*=/{print $2}' ./config.mak | xargs || true)"
if [ -z "${OUTPUT_DIR}" ]; then
  OUTPUT_DIR="output"
fi

cd musl-cross-make
# Outer retry around the whole `make install`. musl-cross-make uses
# `wget -c` for resumption, so a retried run picks up partial tarballs
# rather than redownloading. Belt-and-braces with the wgetrc above:
# wgetrc handles per-request transient errors; this loop covers the
# case where the same tarball fails its full retry budget on a
# completely-down mirror window.
attempt=0
max_attempts=4
until make -j "$(nproc)" install; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge "$max_attempts" ]; then
        echo "build_musl.sh: make install failed after $attempt attempts" >&2
        exit 1
    fi
    backoff=$((attempt * 30))
    echo "build_musl.sh: make install failed (attempt $attempt/$max_attempts), retrying in ${backoff}s..." >&2
    sleep "$backoff"
done

OUTPUT_PATH="${OUTPUT_DIR}"

if [ ! -d "${OUTPUT_PATH}" ]; then
  echo "musl-cross-make output directory not found: ${OUTPUT_PATH}" >&2
  exit 1
fi

mkdir -p /opt/musl
cp -a "${OUTPUT_PATH}/." /opt/musl/
find /opt/musl -iname "*.la" -type f -exec sed -i "s/libdir='/libdir='\/opt\/musl/g" "{}" \;
find /opt/musl -iname "*.la" -type f -exec sed -i "s/installed=yes/installed=no/g" "{}" \;
