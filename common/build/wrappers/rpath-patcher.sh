#!/bin/bash

set -e

# Used with the static C launcher (launcher.c). After packing-initializer has
# merged /opt/shared_libraries into /opt/python/shared_libraries, this script:
#   1. copies the shipped musl runtime libs from the cross-build into
#      /opt/python/shared_libraries/lib/ (so ld-musl-*.so.1 lives with Python)
#   2. rewrites RPATH of every dynamically linked ELF under /opt/python/**/bin/
#      so $ORIGIN-relative lookups resolve inside the installed tree.
#
# No .interp patching is done — the launcher invokes the shipped ld-musl.so.1
# directly via execve, so python-real's .interp is never consulted by the
# kernel. Static binaries (the launcher itself) are skipped.

move_musl_lib() {
    mkdir -p /opt/python/shared_libraries/lib/
    cp -r /opt/musl/*-musl/lib/* /opt/python/shared_libraries/lib/

    # In musl, libc.so IS the dynamic linker. The cross-build sysroot ships
    # libc.so but not always a canonically-named ld-musl-<arch>.so.1 symlink.
    # Ensure the launcher can find it under the conventional name.
    if [ "$IS_32BIT" = "1" ]; then
        musl_ld_name=ld-musl-i386.so.1
    else
        musl_ld_name=ld-musl-x86_64.so.1
    fi
    if [ ! -e "/opt/python/shared_libraries/lib/${musl_ld_name}" ]; then
        ln -sf libc.so "/opt/python/shared_libraries/lib/${musl_ld_name}"
    fi
}

patch_elf_rpath() {
    all_elf_files=$(find /opt/python -type f -path "*bin/*" -executable -exec file {} \; \
        | grep 'ELF' | grep 'dynamically linked' | cut -d: -f1)
    for elf_file in $all_elf_files; do
        elf_file=$(realpath "$elf_file")
        relative_updir_count=$(echo "$elf_file" | grep -o "/" | wc -l)
        relative_updir_count=$(expr "$relative_updir_count" - 3)
        relative_path=""
        for i in $(seq 1 "$relative_updir_count"); do
            relative_path="$relative_path../"
        done
        rpath="\$ORIGIN/${relative_path}shared_libraries/lib:\$ORIGIN/${relative_path}lib"

        patchelf --set-rpath "$rpath" "$elf_file"
        echo "Patched RPATH on $elf_file -> $rpath"
    done
}

main() {
    move_musl_lib
    patch_elf_rpath
}

main
