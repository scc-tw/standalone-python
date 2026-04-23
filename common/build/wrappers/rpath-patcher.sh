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
    # Compute $ORIGIN-relative paths to the two lib trees directly, rather
    # than counting slashes and assuming the binary sits at depth 3 under
    # /opt/python. This stays correct if the layout ever changes.
    shared_lib_dir=/opt/python/shared_libraries/lib
    python_lib_dir=/opt/python/lib

    find /opt/python -type f -path "*bin/*" -executable -exec file {} \; \
        | grep 'ELF' | grep 'dynamically linked' | cut -d: -f1 \
        | while read -r elf_file; do
            elf_file=$(realpath "$elf_file")
            elf_dir=$(dirname "$elf_file")
            rel_shared=$(realpath --relative-to="$elf_dir" "$shared_lib_dir")
            rel_python=$(realpath --relative-to="$elf_dir" "$python_lib_dir")
            rpath="\$ORIGIN/${rel_shared}:\$ORIGIN/${rel_python}"

            patchelf --set-rpath "$rpath" "$elf_file"
            echo "Patched RPATH on $elf_file -> $rpath"
        done
}

main() {
    move_musl_lib
    patch_elf_rpath
}

main
