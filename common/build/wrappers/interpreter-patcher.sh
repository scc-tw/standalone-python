#!/bin/bash

set -e

# The packing-initializer had merge /opt/shared_library into /opt/python/shared_libraries
# So, this script we 
# 1. patch all ELF file's interpreter to out relative musl interpreter
# 2. move all /opt/musl/*-musl/lib/ to /opt/python/shared_libraries/lib/

patch_elf_interpreter() {
    all_elf_files=$(find /opt/python -type f -path "*bin/*" -executable -exec file {} \; | grep ELF | cut -d: -f1)
    for elf_file in $all_elf_files; do
        # Get that elf absolute path
        elf_file=$(realpath $elf_file)
        # calcuate how many ../ we need to go to /opt
        relative_updir_count=$(echo $elf_file | grep -o "/" | wc -l)
        relative_updir_count=$(expr $relative_updir_count - 3)
        # concatenate the relative path to musl interpreter
        relative_path=""
        for i in $(seq 1 $relative_updir_count); do
            relative_path="$relative_path../"
        done
        # Architecture-aware musl interpreter path
        if [ "$IS_32BIT" = "1" ]; then
            musl_interpreter_path=/tmp/StAnDaLoNeMuSlInTeRpReTeR-musl-i386.so
        else
            musl_interpreter_path=/tmp/StAnDaLoNeMuSlInTeRpReTeR-musl-x86_64.so
        fi
        rpath_linker_path="\$ORIGIN/$relative_path/shared_libraries/lib:\$ORIGIN/$relative_path/lib"

        patchelf --set-interpreter $musl_interpreter_path \
            --set-rpath $rpath_linker_path \
            $elf_file
        echo "Patched $elf_file to use $musl_interpreter_path and $rpath_linker_path"
    done
}

move_musl_lib() {
    mkdir -p /opt/python/shared_libraries/lib/
    cp -r /opt/musl/*-musl/lib/* /opt/python/shared_libraries/lib/
}

main() {
    move_musl_lib
    patch_elf_interpreter
}

main