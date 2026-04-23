# FAQ

## Contents
- [General](#general)
- [Installation & usage](#installation--usage)
- [Technical](#technical)
- [Comparison with alternatives](#comparison-with-alternatives)
- [Packages & ecosystem](#packages--ecosystem)
- [Build & development](#build--development)

## General

### What is Standalone Python?

A fully self-contained Python distribution that runs on any Linux system, regardless of the host's libc version. It ships a cross-compiled musl-based Python tree that depends only on the Linux kernel — no glibc, no system libraries, no host packages.

### Why not just install Python via apt/yum?

You might need this project if:

- Your target system has an ancient glibc and modern Python won't run there.
- You can't install system packages (no root, corporate policy, immutable image).
- You need a known-fixed Python environment across disparate hosts.
- You deploy to a mix of distros and don't want six package names.

For regular desktops / servers where you control the package manager, upstream Python is fine.

### Does it work on Alpine?

Yes. Alpine itself uses musl, but our shipped musl is statically bundled, so there's no version conflict with whatever Alpine has installed.

### Does it work in containers?

Yes. The tree is fully relocatable — `COPY --from=…` it into any base image. See [USAGE.md § Docker integration](USAGE.md#in-a-dockerfile-multi-stage).

## Installation & usage

### Where should I install it?

`/opt/python/` is conventional but you can install anywhere with write permission. The tree is position-independent; there are no absolute paths baked into any binary.

### Do I need root to install?

No. `tar -xzf release-…tar.gz -C ~/mytools/` works.

### Do I need to set LD_LIBRARY_PATH or anything?

No. Everything resolves via `$ORIGIN`-relative RPATH baked in at build time.

### Can I have multiple versions installed simultaneously?

Yes — extract each release into its own directory. See [INSTALLATION.md § Multiple versions](INSTALLATION.md#multiple-versions-side-by-side).

### How do I uninstall?

`rm -rf /opt/python` (or wherever you extracted). Nothing is written outside the install directory.

## Technical

### What is the launcher and why does it exist?

`bin/python3` is a statically-linked C binary, not the real CPython. It:

1. Reads `/proc/self/exe` to find its own absolute path.
2. Derives `$prefix/shared_libraries/lib/ld-musl-<arch>.so.1`.
3. `execve`s that ld-musl with `python3.X-real` as its argument.

This lets the distribution be relocatable — the launcher computes all paths at runtime, so moving `/opt/python/` anywhere still works. The real CPython's ELF `PT_INTERP` is never used by the kernel because the launcher doesn't `execve` it directly.

See [ARCHITECTURE.md § The static launcher](ARCHITECTURE.md#the-static-launcher) for the full picture.

### How is this different from the old "/tmp magic file" approach?

Older builds of this project used a shell wrapper that would copy `libc.so` to `/tmp/StAnDaLoNeMuSlInTeRpReTeR-musl-<arch>.so` on first run, and patched Python's `PT_INTERP` to point at that `/tmp` path. That approach required `/tmp` to be writable, wrote a file on every first-run, and had concurrency issues.

The current launcher does everything with `execve` — no `/tmp` writes, no shell fork, works in read-only filesystems.

### Does it use LD_PRELOAD?

No. The musl runtime is invoked via `execve` on the shipped `ld-musl-<arch>.so.1` directly. There is no `LD_PRELOAD` injection.

### What's `pythonX.Y-real`?

The actual CPython binary. It's renamed during build so the launcher can take over the `python3` name. At runtime the launcher `execve`s it indirectly via musl's ld.so.

### What's in `shared_libraries/`?

All the C libraries the Python build links against (OpenSSL, libffi, ncurses, sqlite, etc.) plus the musl C library / dynamic linker. The real Python's RPATH points in here via `$ORIGIN`.

### Does `sys.executable` work correctly?

Yes. Python derives `sys.executable` from `/proc/self/exe` of the process running it, which is the real `pythonX.Y-real`. That's the right answer for most uses (spawning subprocess Pythons, venv creation, etc.).

## Comparison with alternatives

### vs. [python-build-standalone](https://github.com/astral-sh/python-build-standalone)

Both ship portable Python tarballs. Key differences:

| | python-build-standalone | this project |
|--|--|--|
| libc | glibc (default) or musl (optional) | musl only |
| Target compatibility | Depends on glibc version | Any Linux 3.2+ |
| Legacy systems | Fails on old glibc | Works |
| Binary size | Larger (more variants + debug) | Smaller |
| Primary audience | `uv` / `rye` users | legacy / constrained environments |

If you need the broadest compatibility with old systems, use this project. If you need macOS/Windows builds, debug builds, or the vast matrix of Python versions, use python-build-standalone.

### vs. PyInstaller / Nuitka

Those bundle your *application* into a single binary. This project ships a *Python interpreter* you can run arbitrary scripts with. Different goals — use PyInstaller/Nuitka for distributing an app, use this for distributing Python itself.

### vs. Docker with a `python:3.12` image

Docker wraps the whole stack. This project ships a tarball you can drop onto any Linux host (containerised or not). Use Docker if the rest of your infra is already containerised; use this when you can't assume Docker is available on the target.

### vs. pyenv

pyenv *builds* CPython on the host using the host's compilers and libraries. It produces something that depends on the host libc and the libraries that were present at build time. This project produces a binary that depends on neither.

## Packages & ecosystem

### Does pip work?

Yes. Pip is pre-installed. Run `/opt/python/bin/pip3 install …` as usual.

### Do binary wheels work?

Yes, as long as they're compatible with musl. Most popular packages (numpy, pandas, cryptography, pillow, scipy, pyarrow, etc.) publish musl wheels (`*-musllinux_*.whl`). Pip picks the right one automatically.

If a package only ships glibc-manylinux wheels, pip will fall back to source build (which works — see next question).

### Can I install packages that build from source?

Yes. The shipped Python has all the usual build-time bits (Python headers, `setuptools`, a working `distutils`/`sysconfig`). C extensions will compile as long as the host has `gcc` and any package-specific deps (e.g. `libxml2-dev` for lxml-from-source).

### Does pybind11 work? numpy? cryptography?

Yes to all. They use the standard CPython C extension ABI; our Python is a standard CPython.

### Are `.so` extensions resolved correctly?

Yes. Extensions under `site-packages` resolve their NEEDED libraries via RPATH set during build (`$ORIGIN/…/shared_libraries/lib`), so they find the shipped OpenSSL / libffi / etc. out of the box.

For extensions with *other* C-library dependencies not shipped by us (e.g. a package that needs `libpq.so.5` for Postgres), the host needs to provide those, or the package's wheel needs to bundle them.

### How do I upgrade pip?

```
/opt/python/bin/python3 -m pip install --upgrade pip
```

**Not** `/opt/python/bin/pip3 -m pip install --upgrade pip` — pip's own upgrade-hint message suggests that form, but `-m` is a Python flag, and running it through `pip3` errors with `no such option: -m`. Use `python3 -m pip` instead.

## Build & development

### How do I build it myself?

See [BUILD.md](BUILD.md). One line:

```
docker build -f 3.12/x86_64/Dockerfile -t standalone-python:3.12-x86_64 .
```

### How long does a build take?

- Native x86_64 host: 30–60 min per variant (dominated by gcc cross-build).
- Under QEMU (Apple Silicon, other non-x86 hosts): several hours, often OOM-risky.

Use a real x86_64 machine or rely on CI for non-trivial builds.

### Can I change the shipped dependency versions?

Yes — edit the `ENV` block in the per-version `Dockerfile`. Every `build_*.sh` script reads versions via `${VAR:-default}`, so one edit suffices. See [BUILD.md § Customising versions](BUILD.md#customising-versions).

### How are versions pinned across architectures?

Each per-version Dockerfile has its own ENV block. In practice all active Dockerfiles are kept in sync (same OpenSSL, same NCURSES, etc. across `3.{10,11,12}/{x86,x86_64}`), but you *can* diverge them if a specific Python version needs a different dep version.

### I hit an upstream 404 when fetching a tarball.

Common — `zlib.net`, `ftpmirror.gnu.org`, and some SourceForge mirrors age out old versions. Edit `common/build/deplib/build_<dep>.sh` to point at a stable mirror (e.g. `zlib.net/fossils/`, `ftp.gnu.org`). See [BUILD.md § Common gotchas](BUILD.md#common-gotchas).

### Who maintains this project?

See the GitHub repository contributors list. Contributions welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).
