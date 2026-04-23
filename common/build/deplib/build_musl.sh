#!/bin/bash

set -euo pipefail
git clone --depth 1 https://github.com/25077667/musl-cross-make.git

cp ./config.mak musl-cross-make/config.mak

OUTPUT_DIR="$(awk -F= '/^[[:space:]]*OUTPUT[[:space:]]*=/{print $2}' ./config.mak | xargs || true)"
if [ -z "${OUTPUT_DIR}" ]; then
  OUTPUT_DIR="output"
fi

cd musl-cross-make
make -j "$(nproc)" install

OUTPUT_PATH="${OUTPUT_DIR}"

if [ ! -d "${OUTPUT_PATH}" ]; then
  echo "musl-cross-make output directory not found: ${OUTPUT_PATH}" >&2
  exit 1
fi

mkdir -p /opt/musl
cp -a "${OUTPUT_PATH}/." /opt/musl/
find /opt/musl -iname "*.la" -type f -exec sed -i "s/libdir='/libdir='\/opt\/musl/g" "{}" \;
find /opt/musl -iname "*.la" -type f -exec sed -i "s/installed=yes/installed=no/g" "{}" \;
