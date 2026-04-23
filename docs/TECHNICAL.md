# Technical Reference

Facts and specifications. For architectural reasoning see [ARCHITECTURE.md](ARCHITECTURE.md).

## Contents
- [Shipped dependencies](#shipped-dependencies)
- [Musl toolchain](#musl-toolchain)
- [On-disk layout](#on-disk-layout)
- [ELF properties](#elf-properties)
- [Launcher internals](#launcher-internals)
- [Environment variables](#environment-variables)
- [Process startup sequence](#process-startup-sequence)
- [System requirements](#system-requirements)

## Shipped dependencies

All default dep versions (override via per-Dockerfile `ENV` — see [BUILD.md](BUILD.md#customising-versions)):

| Library | Default version | Source | Linked into |
|---------|-----------------|--------|-------------|
| zlib | 1.3.1 | `zlib.net/fossils/` | Python stdlib (`zlib`, `gzip`) |
| libffi | 3.4.4 | libffi GitHub | `ctypes` |
| expat | 2.6.0 | libexpat GitHub | `xml.etree`, `xml.parsers.expat` |
| gdbm | 1.23 | `ftp.gnu.org/gnu/gdbm/` | `dbm.gnu` |
| lzma | 4.32.7 | `tukaani.org/lzma/` | `lzma`, `_lzma` |
| gettext | 0.22.2 | `ftp.gnu.org/gnu/gettext/` | `gettext` |
| ncurses | 6.4 | ring.gr.jp mirror | `curses` |
| openssl | 1.1.1w | openssl.org | `ssl`, `hashlib` (SSL/TLS) |
| readline | 8.2 | ring.gr.jp mirror | `readline` (REPL) |
| tcl | 8.6.13 | SourceForge | `tkinter` |
| xz | 5.4.4 | `tukaani.org/xz/` | `lzma` |
| bzip2 | 1.0.8 | sourceware.org | `bz2` |
| sqlite3 | 3.43.1 | `sqlite.org/YYYY/` | `sqlite3` |
| pip | 23.2.1 | pypa/get-pip | pre-installed |
| setuptools | 65.5.1 | pypa/get-pip | pre-installed |

Defaults are in `common/build/deplib/build_<name>.sh`. Per-Dockerfile `ENV` values override these. A typical current active Dockerfile pins more recent versions (e.g. Python 3.12.13, OpenSSL 3.5.6, zlib 1.3.2, expat 2.7.5, sqlite 3.53.0). Check the `ENV` block of your target Dockerfile for the authoritative list.

## Musl toolchain

Pinned in `<ver>/<arch>/deplib/config.mak`:

```makefile
TARGET  = x86_64-linux-musl     # or i386-linux-musl
GCC_VER = 13.2.0                # some configs: 13.4.0
MUSL_VER = 1.2.4                # some configs: 1.2.6
COMMON_CONFIG += CFLAGS="-g0 -O3" CXXFLAGS="-g0 -O3" LDFLAGS="-s"
GCC_CONFIG    += --enable-default-pie --enable-static-pie
```

Built once per variant via [musl-cross-make](https://github.com/25077667/musl-cross-make) in the `musl_builder` stage. Output lands at `/opt/musl/` inside that stage.

Key flags:
- `-O3` — optimize aggressively; fine for our pre-built libs.
- `-g0` — no debug info. Small binaries.
- `-s` — strip. Combined with `-g0`, ~30% size reduction over defaults.
- `--enable-default-pie --enable-static-pie` — PIE by default; static-PIE supported (used for the launcher).

## On-disk layout

```
/opt/python/                         <- fully relocatable
├── bin/
│   ├── python → python3                (symlink)
│   ├── python3                         (static launcher, ~10 KB)
│   ├── python3.X-real                  (real CPython, dynamic)
│   ├── pip    → pip3                   (symlink)
│   ├── pip3                            (same static launcher, argv[0] dispatch)
│   └── pip3.X-real                     (pip python script)
├── include/python3.X/                  (C headers)
├── lib/
│   ├── libpython3.X.so.1.0             (RPATH: $ORIGIN/../shared_libraries/lib)
│   └── python3.X/
│       ├── (stdlib)
│       ├── lib-dynload/*.so            (extensions, RPATH set)
│       └── site-packages/
└── shared_libraries/
    └── lib/
        ├── libc.so                     (musl libc; also the dynamic linker)
        ├── ld-musl-<arch>.so.1 → libc.so  (canonical name; created by rpath-patcher.sh)
        ├── libssl.so.X, libcrypto.so.X
        ├── libsqlite3.so.0
        ├── libncursesw.so.6, libtinfo.so.6
        ├── libreadline.so.8
        ├── libffi.so.8
        ├── libexpat.so.1
        ├── libbz2.so.1.0, liblzma.so.5
        ├── libtcl8.6.so, libtclstub8.6.a
        ├── libgdbm.so.6
        ├── libstdc++.so.6, libgcc_s.so.1   (from musl toolchain sysroot)
        └── …
```

Nothing outside `/opt/python/` is written at install time, build time, or run time.

## ELF properties

### Static launcher (`bin/python3`, `bin/pip3`)

```
$ file python3
ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, stripped
$ readelf -l python3 | grep -E 'INTERP|LOAD' | head -3
  LOAD   0x000000 0x00400000 ... RWE  0x200000
# No INTERP program header.
```

Because there's no `PT_INTERP`, the kernel runs it directly — no dynamic linker involved.

### Real CPython (`bin/python3.X-real`)

```
$ readelf -l python3.12-real | grep interpreter
      [Requesting program interpreter: /lib/ld-musl-x86_64.so.1]

$ readelf -d python3.12-real | grep -E 'RPATH|RUNPATH|NEEDED'
 0x0000000000000001 (NEEDED)     Shared library: [libpython3.12.so.1.0]
 0x0000000000000001 (NEEDED)     Shared library: [libc.so]
 0x000000000000001d (RUNPATH)    Library runpath: [$ORIGIN/../shared_libraries/lib:$ORIGIN/../lib]
```

The `PT_INTERP` still points at musl's canonical `/lib/` path, but **this path is never consulted by the kernel** — the launcher does `execve` on the shipped ld-musl directly, bypassing it.

`RUNPATH` (rewritten by `rpath-patcher.sh`) is what resolves NEEDED libs at runtime. `$ORIGIN` expands to the real binary's directory (`/opt/python/bin`), so `$ORIGIN/../shared_libraries/lib` resolves to the shipped musl/openssl/etc. Depth is computed per-binary for correct `../` counts on nested files.

### Extension `.so` files (`lib/python3.X/lib-dynload/*.so`, site-packages `.so`)

Same RPATH rewriting treatment. When CPython `dlopen`s them, their NEEDED libs resolve back into `shared_libraries/lib/`.

## Launcher internals

Source: `common/build/wrappers/launcher.c`. ~95 lines of C.

**Compile recipe** (inside `launcher_builder` stage):

```bash
/opt/musl/bin/${MUSL_ARCH}-linux-musl-gcc -static -Os -s \
    -DMUSL_ARCH="\"${MUSL_ARCH}\"" \
    launcher.c -o launcher
```

- `-static` — no dynamic linking, no `.interp`.
- `-Os` — optimize for size.
- `-s` — strip.
- `-DMUSL_ARCH` — baked in as a string literal; decides `ld-musl-<arch>.so.1` at runtime.

**Runtime flow:**

1. `readlink("/proc/self/exe", …)` → absolute path to self.
2. Strip `basename` twice → install prefix (`/opt/python`).
3. Inspect `argv[0]` basename: prefix `python*` → python mode, `pip*` → pip mode.
4. `opendir("$prefix/bin")` → find first entry matching `<prefix>*-real`.
5. Compose `ld_so = "$prefix/shared_libraries/lib/ld-musl-<arch>.so.1"`; `access(ld_so, X_OK)`.
6. Build argv:
   - python mode: `[ld_so, "--argv0", argv[0], python_real, argv[1..]]`
   - pip mode: `[ld_so, "--argv0", argv[0], python_real, pip_real, argv[1..]]`
7. `setenv("PYTHONHOME", prefix, 0)` (only if unset).
8. `execv(ld_so, new_argv)`.

On failure at any step, writes a single line to stderr and exits 127.

`--argv0` is a musl ≥ 1.2.0 feature. It preserves the user-facing process name so `ps`, `/proc/self/cmdline` consumers, and anything reading `sys.argv[0]` see `python3` (or whatever the user typed), not the real binary path.

## Environment variables

Automatically set by the launcher:

| Variable | Value | Notes |
|----------|-------|-------|
| `PYTHONHOME` | install prefix | Only set if not already in environment. |

Respected by Python (standard CPython semantics):

| Variable | Effect |
|----------|--------|
| `PYTHONPATH` | Extra directories on `sys.path`. |
| `PYTHONSTARTUP` | Script to run on REPL start. |
| `PYTHONDONTWRITEBYTECODE` | Don't write `.pyc`. |
| `PYTHONUNBUFFERED` | Unbuffer stdout/stderr. |
| `PYTHONUTF8=1` | Force UTF-8 mode. |
| `PYTHONIOENCODING` | Override stdio encoding. |
| `PYTHONHASHSEED` | Hash randomisation seed. |

SSL-related:

| Variable | Effect |
|----------|--------|
| `SSL_CERT_FILE` | Path to CA bundle. |
| `SSL_CERT_DIR` | Directory of CA certificates. |
| `REQUESTS_CA_BUNDLE` | Only `requests` library. |

Not honoured (no effect):

- `LD_LIBRARY_PATH` against host libs — the real Python's RPATH always wins for the shipped libs, and nothing else needs finding.
- `LD_PRELOAD` — possible in principle but unusual; nothing in the launcher does `LD_PRELOAD` tricks.

## Process startup sequence

Measured latencies (approximate, on modern x86_64):

| Phase | Time | What's happening |
|-------|------|------------------|
| `execve` of launcher | <1 ms | kernel loads ~10 KB static ELF |
| launcher work | <1 ms | readlink, string ops, execve setup |
| `execve` of ld-musl | <1 ms | kernel loads ld.so (~200 KB) |
| ld-musl → Python | 5–15 ms | mmap real CPython, resolve NEEDED libs, call `_start` |
| Python init | 30–80 ms | site.py, `sys.path` setup, default `import site` |
| User code starts | — | |

Total overhead vs. invoking the real Python binary directly: <2 ms. Undetectable in practice.

## System requirements

**Kernel.** Linux ≥ 3.2. This is conservative; musl 1.2.4 itself requires ≥ 2.6.39, so the practical floor is older than most modern distros.

**Architecture.**
- `x86_64`: AMD64 / Intel 64 with SSE2 (universal since ~2005).
- `x86` (i386): 32-bit x86, i686 baseline.

**Disk.** ~200 MB installed (depending on version).

**Memory.** ~15 MB RSS for a bare interpreter; real usage depends on workload.

**Container hosts.** Works inside any Linux container with the default Docker seccomp profile. No `--privileged` or capabilities needed.

**Does NOT require:**

- glibc (any version)
- Root / sudo for install or run
- Network access after install
- Writable `/tmp`
- `/proc` — actually it does; `/proc/self/exe` is read by the launcher. If you're in an unusual sandbox with `/proc` hidden, the launcher falls back to failure. This is a rare edge case.
