#!/bin/bash

# Take a `docker save` output tarball and replace it with the single
# layer blob that carries /opt/python. The shipped image only has a
# couple of FROM stages and `/opt/python` lives in one of them, so the
# layer holding it is by far the largest blob in the save output. We
# rely on that "largest = the one we want" property and ignore the
# enclosing manifest/index/config files.
#
# Works against both docker save layouts:
#   legacy:  <hash>/layer.tar  +  repositories  +  manifest.json
#   OCI:     blobs/sha256/<hash> (opaque blobs, no .tar suffix)
#            + index.json + manifest.json + oci-layout

set -euo pipefail

extract_to_build() {
    local target_file_name=$1
    local target_file_dir=./build

    mkdir -p "$target_file_dir"
    tar -xvf "$target_file_name" -C "$target_file_dir"
    rm -rf "$target_file_name"

    cd "$target_file_dir"

    # Find the largest *regular file* anywhere under the extracted tree.
    # -type f rules out the `blobs/` dir itself (the previous bug:
    # `find -name '*.tar'` returned nothing under OCI layouts, then
    # `xargs ls -l` listed cwd and the largest entry happened to be a
    # directory — which got mv'd onto the target path, breaking gzip).
    local largest_file
    largest_file=$(find . -type f -printf '%s\t%p\n' | sort -nr | head -n 1 | cut -f2-)
    if [ -z "$largest_file" ] || [ ! -f "$largest_file" ]; then
        echo "packing_release_tar: no layer blob found inside $target_file_name" >&2
        exit 1
    fi

    mv "$largest_file" "$target_file_name"
}

main() {
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <target_file_name>" >&2
        exit 1
    fi
    extract_to_build "$1"
}

main "$@"
