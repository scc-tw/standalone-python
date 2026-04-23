#!/bin/bash

set -e
git clone https://github.com/25077667/musl-cross-make.git

cp ./config.mak musl-cross-make/config.mak

cd musl-cross-make && make -j $(nproc) install && cp -r output /opt/musl
find /opt/musl -iname "*.la" -type f -exec sed -i "s/libdir='/libdir='\/opt\/musl/g" "{}" \;
find /opt/musl -iname "*.la" -type f -exec sed -i "s/installed=yes/installed=no/g" "{}" \;
