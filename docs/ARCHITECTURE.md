# System Architecture

How Standalone Python produces a relocatable, libc-independent Python tree.

## Contents
- [Overview](#overview)
- [Design principles](#design-principles)
- [Project layout](#project-layout)
- [Build pipeline](#build-pipeline)
- [The musl cross-toolchain](#the-musl-cross-toolchain)
- [The static launcher](#the-static-launcher)
- [RPATH rewriting](#rpath-rewriting)
- [Runtime behaviour](#runtime-behaviour)
- [Extending the system](#extending-the-system)

## Overview

A built release ships a single directory tree — conventionally `/opt/python/` — that contains:

- A statically-linked C **launcher** at `bin/python3` and `bin/pip3`.
- The **real** CPython interpreter at `bin/pythonX.Y-real` (dynamically linked against musl).
- A shipped **musl runtime** under `shared_libraries/lib/` (`libc.so`, `ld-musl-<arch>.so.1`, C++ stdlib, etc.).
- The CPython standard library and any extension modules under `lib/pythonX.Y/`.

At invocation time:

```
user → /opt/python/bin/python3            # static C launcher
     → execve(ld-musl-<arch>.so.1,        # shipped dynamic linker
         ["--argv0", "python3",
          "/opt/python/bin/pythonX.Y-real",  # real CPython
          ...user args])
     → CPython runs, loads .so extensions via RPATH=$ORIGIN/…/shared_libraries/lib
```

The kernel never executes the real CPython directly, so its `PT_INTERP` is never consulted. Nothing is written to `/tmp`. The tree is fully relocatable — copy `/opt/python/` anywhere and it still works.

## Design principles

1. **libc isolation.** Python is built against a cross-compiled musl, not the host glibc. The dynamic linker it needs ships with it.
2. **No host contract.** The distribution makes no assumptions about host files, paths, or libraries.
3. **Kernel-only requirement.** A recent-enough Linux kernel is the only runtime prerequisite.
4. **Relocatable.** All internal references are `$ORIGIN`-relative so the install path can change.
5. **Auditable versions.** Every shipped dependency version is declared in the per-version `Dockerfile`.

## Project layout

```
standalone-python/
├── 3.10/                         # per-version, per-arch Dockerfiles
│   ├── x86/
│   │   ├── Dockerfile
│   │   └── deplib/config.mak     # musl-cross-make config (TARGET, GCC_VER, MUSL_VER)
│   └── x86_64/
│       ├── Dockerfile
│       └── deplib/config.mak
├── 3.11/…
├── 3.12/…
├── common/
│   ├── build/
│   │   ├── deplib/               # shared dependency build scripts
│   │   │   ├── build_zlib.sh
│   │   │   ├── build_ffi.sh
│   │   │   ├── build_openssl.sh
│   │   │   ├── …                 # 16 build_*.sh + install_pip.sh
│   │   │   └── build_musl.sh
│   │   └── wrappers/
│   │       ├── launcher.c            # static C launcher source
│   │       ├── packing-initializer   # renames pythonX.Y → pythonX.Y-real
│   │       └── rpath-patcher.sh      # rewrites RPATH, installs musl runtime
│   └── patches/common/ncurses/
│       └── fix-ncurses-underlinking.patch
├── ci/
│   └── packing_release_tar.sh    # extracts /opt/python from docker save output
├── .github/workflows/build.yml
└── .gitlab-ci.yml
```

Each of the six per-version directories (`3.10/x86`, `3.10/x86_64`, `3.11/x86`, `3.11/x86_64`, `3.12/x86`, `3.12/x86_64`) contains only a `Dockerfile` and a `deplib/config.mak`. All build logic lives in `common/`.

## Build pipeline

The Dockerfile for each variant is a linear chain of ~17 stages. The build context is **the repo root**; the Dockerfile is selected with `-f`:

```
docker build -f 3.12/x86_64/Dockerfile -t standalone-python:3.12-x86_64 .
```

Stages (top to bottom):

| # | Stage | Base | What it does |
|---|-------|------|--------------|
| 1 | `base_builder` | `amd64/alpine:3.18.3` (or `i386/alpine`) | Alpine toolchain: gcc, make, etc. Declares every dep's version in `ENV`. |
| 2 | `musl_builder` | `amd64/debian:bookworm` (or `i386/debian`) | Cross-compiles a musl toolchain (gcc + musl) via [musl-cross-make](https://github.com/25077667/musl-cross-make). |
| 3–15 | `libz_builder`, `ffi_builder`, `expat_builder`, `gdbm_builder`, `lzma_builder`, `gettext_builder`, `ncurses_builder`, `openssl_builder`, `readline_builder`, `tcl_builder`, `xz_builder`, `bzip2_builder`, `sqlite3_builder` | each `FROM` the previous stage | Builds each dependency into `/opt/shared_libraries`. |
| 16 | `python_builder` | `FROM sqlite3_builder` | Compiles CPython against all shipped deps; runs `install_pip.sh`. |
| 17 | `launcher_builder` | `FROM musl_builder` | Cross-compiles `launcher.c` statically with the shipped musl toolchain. |
| 18 | `patch_stage` | `amd64/debian:latest` | Assembles the final tree: runs `packing-initializer`, installs the launcher, copies in musl runtime, runs `rpath-patcher.sh`. |
| 19 | `final` | `amd64/debian:latest` | Copies only `/opt/python/` out. This is what ships. |

Stages 3–15 form one long chain so every dependency is visible to the next. This is also what makes Docker's layer cache useful — rebuilding after bumping e.g. `TCL_VERSION` re-runs only tcl-onward.

## The musl cross-toolchain

`musl-cross-make` builds a GCC that targets musl. Pinned in `deplib/config.mak`:

```makefile
TARGET  = x86_64-linux-musl           # or i386-linux-musl
GCC_VER = 13.2.0                      # or 13.4.0 on newer configs
MUSL_VER = 1.2.4                      # or 1.2.6
COMMON_CONFIG += CFLAGS="-g0 -O3" CXXFLAGS="-g0 -O3" LDFLAGS="-s"
GCC_CONFIG    += --enable-default-pie --enable-static-pie
```

The toolchain is built once per variant in the `musl_builder` stage and its output (`/opt/musl/`) is then reused by both `python_builder` (via the earlier stage chain's compiler setup) and `launcher_builder` (directly, for the static launcher).

## The static launcher

`common/build/wrappers/launcher.c` compiles to a ~10 KB static ELF with no `PT_INTERP`. It replaces what used to be two shell wrappers (`python-wrapper`, `pip-wrapper`).

**Flow:**

```c
readlink("/proc/self/exe", …)                 // /opt/python/bin/python3
prefix    = dirname(dirname(exe))             // /opt/python
ld_so     = $prefix/shared_libraries/lib/ld-musl-<arch>.so.1
python_real = find("python*-real" in bin/)
pip_real    = find("pip*-real"    in bin/)   // only for pip3 mode

if (argv[0] basename starts with "pip")
    execv(ld_so, [ld_so, "--argv0", argv[0], python_real, pip_real, argv[1..]]);
else
    execv(ld_so, [ld_so, "--argv0", argv[0], python_real,            argv[1..]]);
```

Key properties:

- The launcher's own `.interp` is absent (statically linked), so it runs on any Linux kernel regardless of host libc.
- It invokes the shipped musl dynamic linker **directly** via `execve`. The kernel reads musl's own `PT_INTERP` (which points at itself — musl's `libc.so` is both libc and ld.so), and musl then loads `pythonX.Y-real` as a regular program. Python's own `.interp` is never consulted by the kernel.
- `--argv0` (musl ≥ 1.2.0 feature) preserves the user-facing process name so `ps`, `sys.argv[0]`, and `sys.executable`-derived paths look right.
- `/proc/self/exe` makes the whole chain location-independent.

Build-time the launcher is compiled against the shipped musl:

```dockerfile
FROM musl_builder AS launcher_builder
ENV MUSL_ARCH=x86_64
COPY common/build/wrappers/launcher.c /src/launcher.c
RUN /opt/musl/bin/${MUSL_ARCH}-linux-musl-gcc -static -Os -s \
      -DMUSL_ARCH="\"${MUSL_ARCH}\"" \
      /src/launcher.c -o /src/launcher
```

## RPATH rewriting

`common/build/wrappers/rpath-patcher.sh` runs in `patch_stage` and does three things:

1. **Copy the musl runtime:** `cp -r /opt/musl/*-musl/lib/* /opt/python/shared_libraries/lib/`
2. **Create the canonical linker symlink:** `ln -s libc.so ld-musl-<arch>.so.1` (because musl's `libc.so` *is* its dynamic linker).
3. **Rewrite RPATH on every dynamic ELF under `/opt/python/**/bin/`**:
   ```
   RPATH = $ORIGIN/…/shared_libraries/lib:$ORIGIN/…/lib
   ```
   The `…` depth is computed from each file's own path so deeply-nested binaries still resolve. Static ELFs (the launcher itself) are filtered out — patchelf is only run on ones marked `dynamically linked`.

Notably **no `.interp` patching happens**. The real Python's `.interp` retains whatever musl-cross-make set (typically `/lib/ld-musl-<arch>.so.1`), but nothing ever `execve`s the Python binary directly — the launcher always goes through the shipped ld-musl first.

## Runtime behaviour

On `/opt/python/bin/python3 script.py`:

1. Kernel loads the launcher (static ELF, no ld.so needed).
2. Launcher reads `/proc/self/exe`, derives paths, calls `execve` on `shared_libraries/lib/ld-musl-x86_64.so.1` with argv constructed for `pythonX.Y-real`.
3. Kernel loads ld-musl. ld-musl reads its argv, mmap's `pythonX.Y-real`, resolves the binary's NEEDED libs (`libpython3.X.so.1.0`, `libssl.so.3`, `libcrypto.so.3`, etc.) via the binary's `RPATH` — which resolves `$ORIGIN/../…/shared_libraries/lib` → `/opt/python/shared_libraries/lib/`.
4. CPython starts. `sys.executable` points to `/opt/python/bin/pythonX.Y-real` (via `/proc/self/exe`). `sys.path` / `sys.prefix` derive from there.
5. On `import numpy`, CPython `dlopen`s `numpy/core/_multiarray_umath.so`. Extension's NEEDED libs are resolved via RPATH inherited from the main binary plus its own, all pointing back into `shared_libraries/lib/`.

No `/tmp` writes. No host libraries touched. No shell forked for wrapping.

## Extending the system

**Bump a dep version:** edit the `ENV` block at the top of the per-version Dockerfile. Every stage that uses that dep inherits the env var and the corresponding `build_<dep>.sh` uses `${DEP_VERSION:-default}`. No script edits needed.

**Add a new Python minor version:** copy a sibling per-version dir (e.g. `3.12/x86_64/` → `3.13/x86_64/`), adjust the `PYTHON_VERSION` env and `deplib/config.mak` if toolchain changes; the CI matrix picks it up.

**Add a new arch:** create `3.X/<arch>/Dockerfile` + `deplib/config.mak`. `launcher.c`'s arch handling is controlled by the `MUSL_ARCH` define (currently `x86_64` or `i386`); add a new value if introducing another arch. Prefix base images with the correct Docker arch name (`amd64`, `i386`, `arm64v8`, etc.).

**Swap a dependency:** edit the shared `common/build/deplib/build_<dep>.sh`. All six Dockerfiles pick up the change automatically.

See [BUILD.md](BUILD.md) for concrete build recipes and [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow.
