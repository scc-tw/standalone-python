# Contributing

Guide for contributors. Assumes familiarity with [ARCHITECTURE.md](ARCHITECTURE.md) and [BUILD.md](BUILD.md).

## Contents
- [Development setup](#development-setup)
- [Project structure](#project-structure)
- [Making changes](#making-changes)
- [Testing](#testing)
- [Coding style](#coding-style)
- [Commit messages](#commit-messages)
- [Pull requests](#pull-requests)

## Development setup

Clone and build one variant:

```bash
git clone https://github.com/25077667/standalone-python.git
cd standalone-python

# Pick the smallest variant for iteration speed
docker build -f 3.12/x86_64/Dockerfile -t standalone-python:3.12-x86_64 .
```

A cold build takes 30–60 min on a native x86_64 host (dominated by the `musl_builder` stage compiling gcc from source). Subsequent builds are fast because Docker caches every stage.

## Project structure

```
standalone-python/
├── 3.10/, 3.11/, 3.12/            # per-version, per-arch configs
│   └── {x86, x86_64}/
│       ├── Dockerfile             # ENV block declares all dep versions
│       └── deplib/config.mak      # musl-cross-make config
├── common/
│   ├── build/
│   │   ├── deplib/                # one build_<name>.sh per dep (SHARED)
│   │   └── wrappers/
│   │       ├── launcher.c         # static C launcher source
│   │       ├── packing-initializer
│   │       └── rpath-patcher.sh
│   └── patches/common/ncurses/fix-ncurses-underlinking.patch
├── ci/packing_release_tar.sh      # release tarball extractor
├── docs/                          # you are here
├── .github/workflows/build.yml
└── .gitlab-ci.yml
```

**Key rule:** per-version directories contain *only* `Dockerfile` + `deplib/config.mak`. Anything shared across versions lives in `common/`. If you find yourself copying a file between per-version dirs, it belongs in `common/`.

## Making changes

### Bump a dependency version

Edit the relevant `ENV` line in the per-version `Dockerfile`. Example — bump OpenSSL in all builds:

```dockerfile
# In each of 3.{10,11,12}/x86{,_64}/Dockerfile
ENV ...
    OPENSSL_VERSION=3.5.6 \     # ← this
    ...
```

Rebuild, smoke-test:

```bash
docker build --no-cache -f 3.12/x86_64/Dockerfile -t standalone-python:3.12-x86_64 .
docker run --rm standalone-python:3.12-x86_64 \
    /opt/python/bin/python3 -c 'import ssl; print(ssl.OPENSSL_VERSION)'
```

No changes to `common/build/deplib/build_openssl.sh` are needed — it reads `${OPENSSL_VERSION:-1.1.1w}`.

### Swap a dependency's build logic

Edit the shared `common/build/deplib/build_<name>.sh`. Keep the `${VAR:-default}` pattern so the Dockerfile's `ENV` still controls the version.

All six Dockerfiles pick up the change automatically.

### Add a new Python minor version (e.g. 3.13)

1. `cp -r 3.12 3.13`
2. In `3.13/x86_64/Dockerfile` and `3.13/x86/Dockerfile`, update `PYTHON_VERSION=3.13.x`.
3. Verify the `deplib/config.mak` toolchain pins are still compatible with the new CPython (check the CPython release notes).
4. Add the version to the CI matrix in `.github/workflows/build.yml` and `.gitlab-ci.yml`.
5. Smoke-test both arches locally.

### Add a new architecture (e.g. arm64)

1. Create `3.X/arm64/` directories with `Dockerfile` and `deplib/config.mak`.
2. In `config.mak`: `TARGET = aarch64-linux-musl`.
3. In `Dockerfile`: use `arm64v8/alpine:...` and `arm64v8/debian:...` as base images; set `IS_32BIT=0`; set `MUSL_ARCH=aarch64` in `launcher_builder`.
4. Extend the CI matrix.
5. Note that `launcher.c`'s dispatch currently special-cases `pip3` detection via prefix only — should be arch-agnostic, but verify by running `file /opt/python/bin/python3` on the built image.

### Change the launcher

Edit `common/build/wrappers/launcher.c`. Keep it **static**, **minimal**, and **arch-parametric via `MUSL_ARCH`**. After changes:

```bash
# Local compile check with your host's musl-gcc (Alpine or musl-tools)
musl-gcc -static -Os -s -DMUSL_ARCH='"x86_64"' common/build/wrappers/launcher.c -o /tmp/l
file /tmp/l     # should say "statically linked"

# Full integration test via docker build
docker build --no-cache -f 3.12/x86_64/Dockerfile -t test .
docker run --rm test /opt/python/bin/python3 --version
docker run --rm test /opt/python/bin/pip3 --version
```

### Change the ELF post-processing

`common/build/wrappers/rpath-patcher.sh` runs in `patch_stage`. It (a) copies musl libs, (b) creates the `ld-musl-<arch>.so.1` symlink, (c) rewrites RPATH on dynamic ELFs. Don't re-introduce `.interp` patching — the launcher architecture depends on NOT touching `PT_INTERP`.

## Testing

Minimum test before sending a PR:

```bash
# 1. Build
docker build -f <path>/Dockerfile -t test .

# 2. Stdlib smoke
docker run --rm test /opt/python/bin/python3 \
    -c 'import ssl, sqlite3, ctypes, lzma, bz2, readline, curses; print("ok")'

# 3. Pip works
docker run --rm test /opt/python/bin/pip3 --version

# 4. Relocatable — extract the image and run from elsewhere
docker run --rm test sh -c '
    cp -r /opt/python /tmp/py &&
    /tmp/py/bin/python3 -c "import sys; print(sys.executable, sys.version)"
'

# 5. Launcher is static (didn't regress to dynamic)
docker run --rm test file /opt/python/bin/python3 | grep -q 'statically linked'
```

For changes touching multiple variants (e.g. launcher code, `rpath-patcher.sh`, or `common/build/deplib/*`), build *at least* one x86_64 and one x86 variant. The x86 path exercises `IS_32BIT=1` code paths in several scripts.

## Coding style

### Shell scripts (`common/build/**/*.sh`)

- `#!/bin/sh` by default; `#!/bin/bash` only if bash-specific features are needed (arrays, `[[ ]]`, etc.).
- `set -e` at the top.
- `${VAR:-default}` for every version pin / user-overridable value.
- No interactive features (no prompts, no colours).
- One external tarball fetch per script.

### C (`launcher.c`)

- POSIX-ish, no GNU-only features where avoidable.
- No dynamic allocation unless necessary; `PATH_MAX`-sized stack buffers are fine.
- Every syscall checked. Failure path: one-line stderr via `die()`, exit 127.
- Keep it tiny. If it grows past ~200 lines, that's a warning sign.

### Dockerfiles

- Keep the 17-stage pipeline shape. Don't collapse stages for "simplicity" — each stage is a cache checkpoint.
- ENV blocks use `\` continuations and alphabetical-ish grouping.
- Image references are arch-prefixed (`amd64/alpine`, `i386/debian`) — no `--platform` flags.

### Markdown docs

- Short headings, use code fences for every example.
- Links use repo-relative paths.
- No emoji in headings (they muddle anchors).

## Commit messages

Format:

```
<short imperative subject line>

Optional body with the why.

Fixes #123
```

Subject ≤ 72 chars. Imperative mood (`Fix foo`, not `Fixed foo`).

Prefix convention (optional but helpful):

- `build:` Dockerfile / build-logic changes
- `deps:` dep version bumps or swap
- `launcher:` launcher.c or related
- `ci:` workflow / pipeline changes
- `docs:` documentation
- `fix:` bugfix in shipped code (i.e. shell scripts, launcher)

## Pull requests

Checklist:

- [ ] Built and tested locally (at least the changed variants)
- [ ] Smoke tests pass inside the built image
- [ ] No files added to per-version dirs beyond `Dockerfile` + `deplib/config.mak`
- [ ] If touching `common/`, all six Dockerfiles still build
- [ ] Docs updated if behaviour/architecture changed
- [ ] CI passes

Small, focused PRs. One bump per PR ideally; grouped bumps are fine if they're coordinated (e.g. OpenSSL 3.x migration touching several files).

Thanks for contributing.
