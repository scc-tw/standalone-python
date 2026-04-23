# Installation Guide

Download, install, and verify Standalone Python.

## Contents
- [Requirements](#requirements)
- [Download](#download)
- [Install](#install)
- [Verify](#verify)
- [What's in the tree](#whats-in-the-tree)
- [Multiple versions side by side](#multiple-versions-side-by-side)
- [Uninstall](#uninstall)

## Requirements

- **Linux kernel** ≥ 3.2 (2012+). The kernel is the *only* host requirement.
- **CPU**: x86_64 or x86 (i386). ARM builds are not shipped.
- **Disk**: ~200 MB per installed version.
- **Permissions**: write access to your chosen install directory.

Explicitly not required:
- ❌ `glibc` (any version) — the distribution ships its own musl.
- ❌ Root access — install anywhere you can write.
- ❌ Package manager — tarball extraction only.
- ❌ Python on the host.

## Download

Grab a release tarball from [GitHub Releases](https://github.com/25077667/standalone-python/releases):

```
release-3.12-x86_64.tar.gz
release-3.12-x86.tar.gz
release-3.11-x86_64.tar.gz
…
```

Or build one yourself — see [BUILD.md](BUILD.md).

## Install

Extract anywhere. The tarball contains a top-level `opt/python/`:

```bash
# System-wide under /opt (needs sudo)
sudo tar -xzf release-3.12-x86_64.tar.gz -C /

# Into your home directory
mkdir -p ~/tools && tar -xzf release-3.12-x86_64.tar.gz -C ~/tools
# Python is now at ~/tools/opt/python/bin/python3

# Ad-hoc — just untar in place
tar -xzf release-3.12-x86_64.tar.gz
./opt/python/bin/python3 --version
```

The tree is fully relocatable. You can move or rename the containing directory at any time; nothing inside references an absolute install path.

Optionally add to `PATH`:

```bash
# ~/.bashrc or ~/.zshrc
export PATH="/opt/python/bin:$PATH"
```

## Verify

```bash
$ /opt/python/bin/python3 --version
Python 3.12.x

$ /opt/python/bin/python3 -c 'import ssl, sqlite3, lzma, bz2, ctypes; print("stdlib ok")'
stdlib ok

$ /opt/python/bin/pip3 --version
pip X.Y.Z from /opt/python/lib/python3.12/site-packages/pip (python 3.12)
```

Confirm the library-independence:

```bash
$ ldd /opt/python/bin/python3
    not a dynamic executable            # the launcher is static
$ ldd /opt/python/bin/python3.12-real
    linux-vdso.so.1 (0x…)
    libpython3.12.so.1.0 => /opt/python/lib/libpython3.12.so.1.0 (…)
    libssl.so.3          => /opt/python/shared_libraries/lib/libssl.so.3 (…)
    …
    /opt/python/shared_libraries/lib/ld-musl-x86_64.so.1 (…)   # shipped ld.so
```

No `/lib`, `/usr/lib`, `/lib64` entries — everything resolves inside the install tree.

## What's in the tree

```
opt/python/
├── bin/
│   ├── python          → python3     (symlink)
│   ├── python3         (static C launcher)
│   ├── python3.12-real (real CPython, dynamically linked to musl)
│   ├── pip             → pip3        (symlink)
│   ├── pip3            (same static launcher; argv[0] selects pip mode)
│   └── pip3.12-real    (real pip python script)
├── include/              (CPython headers)
├── lib/
│   ├── libpython3.12.so.1.0
│   └── python3.12/       (stdlib + site-packages)
└── shared_libraries/
    └── lib/
        ├── libc.so
        ├── ld-musl-x86_64.so.1 → libc.so   (musl's ld.so)
        ├── libssl.so.3, libcrypto.so.3
        ├── libsqlite3.so.0
        ├── libncursesw.so.6
        └── …                               (every shipped dep)
```

The `-real` suffix names exist because `python3` is the launcher; the launcher locates and execs `python3.12-real` via the shipped `ld-musl-x86_64.so.1`.

## Multiple versions side by side

Install under different prefixes:

```bash
sudo tar -xzf release-3.10-x86_64.tar.gz -C /opt/py310 --strip-components=0
# /opt/py310/opt/python/bin/python3

# or cleaner — strip the top-level opt/
sudo mkdir -p /opt/py310
sudo tar -xzf release-3.10-x86_64.tar.gz -C /opt/py310 --strip-components=1
# /opt/py310/python/bin/python3
```

Each install tree is completely self-contained; there is no shared state between versions.

## Uninstall

Plain `rm`:

```bash
sudo rm -rf /opt/python
```

Nothing is written outside the install directory. No `/tmp` files, no dotfiles, no systemd units, no symlinks anywhere else.

(Earlier versions of this project created a `/tmp/StAnDaLoNeMuSlInTeRpReTeR-musl-*.so` file on first run. The current release does not — you can ignore any instructions telling you to clean that up.)
