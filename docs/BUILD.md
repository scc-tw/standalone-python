# Build Instructions

Everything needed to build a Standalone Python distribution locally.

## Contents
- [Prerequisites](#prerequisites)
- [One-line build](#one-line-build)
- [The build in detail](#the-build-in-detail)
- [Customising versions](#customising-versions)
- [Customising the toolchain](#customising-the-toolchain)
- [Testing a fresh build](#testing-a-fresh-build)
- [Extracting the tarball](#extracting-the-tarball)
- [Common gotchas](#common-gotchas)

## Prerequisites

- **Docker** (with BuildKit enabled — default for Docker ≥ 23).
- Sufficient disk space: ~5 GB per variant for build cache; final image ~300 MB.
- Sufficient time: ~30–60 min natively on x86_64, multi-hour under QEMU emulation (e.g. on Apple Silicon, see [Common gotchas](#common-gotchas)).

No other host dependencies — everything compiles inside containers.

## One-line build

From the repo root:

```bash
docker build -f 3.12/x86_64/Dockerfile -t standalone-python:3.12-x86_64 .
```

Substitute any combination of `{3.10, 3.11, 3.12}` × `{x86, x86_64}`.

The context is the **repo root** (`.`), which is why `-f` is required to point at the specific Dockerfile. The Dockerfile `COPY`s reach into `common/` for shared scripts.

## The build in detail

Each per-version Dockerfile runs through these stages (top to bottom, mostly sequential):

1. **`base_builder`** — Alpine with build tools; declares every dep version in `ENV`.
2. **`musl_builder`** — Debian + [musl-cross-make](https://github.com/25077667/musl-cross-make); builds a full gcc + musl toolchain into `/opt/musl`.
3. **`{zlib, ffi, expat, gdbm, lzma, gettext, ncurses, openssl, readline, tcl, xz, bzip2, sqlite3}_builder`** — each `FROM` the previous stage; each installs into `/opt/shared_libraries`.
4. **`python_builder`** — compiles CPython linked against everything above; runs `install_pip.sh`.
5. **`launcher_builder`** — compiles `common/build/wrappers/launcher.c` statically with the shipped musl-gcc.
6. **`patch_stage`** — runs `packing-initializer` (renames `pythonX.Y` → `pythonX.Y-real`), installs the launcher as both `python3` and `pip3`, copies the musl runtime into `/opt/python/shared_libraries/lib/`, runs `rpath-patcher.sh` to rewrite RPATH on dynamic ELFs.
7. **`final`** — single `COPY --from=patch_stage /opt/python /opt/python`; this is what the tag points to.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the reasoning behind each piece.

## Customising versions

All shipped dependency versions are declared in the **per-version Dockerfile's `base_builder` ENV block** and flow through every stage that needs them. To change one:

```dockerfile
# In 3.12/x86_64/Dockerfile
ENV ...
    OPENSSL_VERSION=3.5.6 \      # change this line
    ...
```

The build scripts (`common/build/deplib/build_*.sh`) read these with `${VAR:-default}`, so changing the Dockerfile suffices — no script edits needed.

Parameterised variables (with current defaults in scripts):

| Variable | Script | Default |
|----------|--------|---------|
| `ZLIB_VERSION` | `build_zlib.sh` | `1.3.1` |
| `FFI_VERSION` | `build_ffi.sh` | `3.4.4` |
| `EXPAT_VERSION` | `build_expat.sh` | `2.6.0` |
| `EXPAT_LITERIAL_VERSION` | `build_expat.sh` | auto-derived from `EXPAT_VERSION` |
| `GDBM_VERSION` | `build_gdbm.sh` | `1.23` |
| `LZMA_VERSION` | `build_lzma.sh` | `4.32.7` |
| `GETTEXT_VERSION` | `build_gettext.sh` | `0.22.2` |
| `NCURSES_VERSION` | `build_ncurses.sh` | `6.4` |
| `OPENSSL_VERSION` | `build_openssl.sh` | `1.1.1w` |
| `READLINE_VERSION` | `build_readline.sh` | `8.2` |
| `TCL_VERSION` | `build_tcl.sh` | `8.6.13` |
| `XZ_VERSION` | `build_xz.sh` | `5.4.4` |
| `BZIP2_VERSION` | `build_bzip2.sh` | `1.0.8` |
| `SQLITE_VERSION` | `build_sqlite3.sh` | `3430100` (numeric) |
| `SQLITE_VERSION_LITERIAL` | `build_sqlite3.sh` | `3.43.1` (dotted) |
| `SQLITE_YEAR` | `build_sqlite3.sh` | `2023` (URL segment) |
| `PYTHON_PIP_VERSION` | `install_pip.sh` | `23.2.1` |
| `PYTHON_SETUPTOOLS_VERSION` | `install_pip.sh` | `65.5.1` |

Each active Dockerfile typically overrides all of these to the current pinned version. Defaults in the scripts are safety fallbacks.

You can also override at the docker-build command line:

```bash
docker build -f 3.12/x86_64/Dockerfile \
  --build-arg OPENSSL_VERSION=3.5.6 \
  -t standalone-python:3.12-x86_64 .
```

(Requires adding `ARG OPENSSL_VERSION` to the Dockerfile before the `ENV` line.)

## Customising the toolchain

`deplib/config.mak` controls musl-cross-make:

```makefile
TARGET = x86_64-linux-musl
GCC_VER = 13.2.0
MUSL_VER = 1.2.4
COMMON_CONFIG += CFLAGS="-g0 -O3" CXXFLAGS="-g0 -O3" LDFLAGS="-s"
GCC_CONFIG    += --enable-default-pie --enable-static-pie
```

Edit this per-arch file to bump gcc or musl, or change compiler flags. The `launcher_builder` stage uses the same toolchain, so a bump here affects both Python and the launcher.

## Testing a fresh build

```bash
# Smoke test the golden extensions
docker run --rm standalone-python:3.12-x86_64 \
    /opt/python/bin/python3 -c 'import ssl, sqlite3, ctypes, lzma, bz2, readline; print("ok")'

# Pip works
docker run --rm standalone-python:3.12-x86_64 \
    /opt/python/bin/pip3 --version

# Confirm portability: mv the tree somewhere else and rerun
docker run --rm standalone-python:3.12-x86_64 sh -c '
    cp -r /opt/python /tmp/py &&
    /tmp/py/bin/python3 -c "import ssl; print(ssl.OPENSSL_VERSION)"
'

# Confirm the launcher is really static (no .interp)
docker run --rm standalone-python:3.12-x86_64 \
    file /opt/python/bin/python3
# → ELF 64-bit LSB executable, x86-64, ..., statically linked ...
```

## Extracting the tarball

The image isn't the final artefact — the tarball is. CI does this via `ci/packing_release_tar.sh`:

```bash
docker save standalone-python:3.12-x86_64 > image.tar
./ci/packing_release_tar.sh image.tar
# → ./build/release-3.12-x86_64.tar   (contains opt/python/)
gzip -9 build/release-3.12-x86_64.tar
```

The resulting tarball extracts to `opt/python/` and can be moved anywhere on any Linux host.

## Common gotchas

**Apple Silicon (aarch64) host.** `amd64/*` and `i386/*` images run under QEMU emulation. Builds work but take multi-hour, mostly in the `musl_builder` stage (a full gcc build under QEMU). If just validating structural changes, build on a native x86_64 host or use CI.

**Upstream URL rot.** Several sources are historically flaky:
- `zlib.net/` → only the latest release; older versions moved to `zlib.net/fossils/`.
- `ftpmirror.gnu.org` → does geo-based redirects; can land on a mirror that blocks your IP. Prefer canonical `ftp.gnu.org`.
- `tukaani.org/lzma/` → the lzma 4.32.7 tarball's `config.guess` predates aarch64; it only builds under x86 platforms. That's fine — that's the only platform we target.

Sources currently used in `common/build/deplib/*.sh` already apply these workarounds. If a build fails with a 404 or 403 from a tarball fetch, swap the URL.

**`--no-cache` after toolchain changes.** Docker's layer cache keys by the `RUN` line, not by the shipped musl version. If you bump `GCC_VER` or `MUSL_VER` in `deplib/config.mak`, the `musl_builder` layer may still cache the old toolchain. Force a rebuild with `--no-cache` or prune the `musl_builder` layer.

**Smoke tests matter.** `docker build` succeeding doesn't mean Python works. Always run the smoke test above — the failure mode for a broken extension is often "image builds fine, `import ssl` fails at runtime."
