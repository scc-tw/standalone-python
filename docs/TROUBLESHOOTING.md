# Troubleshooting

Symptoms, diagnoses, and fixes. Organised by where the problem manifests.

## Contents
- [Installation / extraction](#installation--extraction)
- [Running Python](#running-python)
- [Importing modules](#importing-modules)
- [pip](#pip)
- [Building from source](#building-from-source)
- [Debugging techniques](#debugging-techniques)
- [Error reference](#error-reference)

## Installation / extraction

### `tar: error` during extraction

Usually a truncated download. Check the file size against the release page. Re-download with `curl -L -O`.

### Extraction succeeds but `ls opt/python/` is empty

You extracted into the wrong directory. The tarball contains a top-level `opt/python/`, not just the contents of `python/`. Check with `tar tf release-…tar.gz | head`.

### "Permission denied" running `bin/python3`

Check the file was extracted with its executable bit:

```
$ ls -l /opt/python/bin/python3
-rwxr-xr-x … python3       # good
-rw-r--r-- … python3       # bad — use tar, not cp from a Windows-exported zip
```

Fix: `chmod +x /opt/python/bin/python3 /opt/python/bin/pip3 /opt/python/bin/*-real`.

## Running Python

### `./python3: No such file or directory` (with the file clearly existing)

This specific error on an *existing* static binary usually means something weird is wrong — the file might actually be a broken symlink. Run `file /opt/python/bin/python3`:

```
ELF 64-bit LSB executable, x86-64, ..., statically linked, stripped
```

Expected — the launcher is static. If you see "dynamically linked" or "symbolic link to …" broken target, re-extract the tarball.

### `standalone-python launcher: <path>: ...` error

The static launcher prints diagnostics starting with `standalone-python launcher:` and exits 127. Common messages:

- `readlink /proc/self/exe: ...` — `/proc` is not mounted. Rare; happens in unusual sandboxes. Mount `/proc` inside the sandbox.
- `<ld_so_path>: No such file or directory` — the shipped musl ld.so is missing. Check `ls /opt/python/shared_libraries/lib/ld-musl-*.so.1`. If missing, the tarball is incomplete or the `rpath-patcher.sh` step didn't run. Re-download or rebuild.
- `could not locate python*-real in bin dir` — the real Python binary is missing. Check `ls /opt/python/bin/python*-real`. Re-extract.

### `Illegal instruction` or segfault on startup

The binary was built for a different CPU class. x86_64 builds require SSE2 (universal since ~2005). x86 builds require i686. Check with `uname -m` and match to the release variant.

### Very old kernel errors, e.g. `FATAL: kernel too old`

musl 1.2.x requires Linux ≥ 2.6.39 (practical floor). If you see this message, you're on Linux 2.6.x or earlier. This project doesn't support those.

## Importing modules

### `ImportError: libssl.so.X: cannot open shared object file`

The shipped OpenSSL wasn't found. Check RPATH on the real Python:

```
$ readelf -d /opt/python/bin/python3.12-real | grep -E 'RUNPATH|RPATH'
 0x000000000000001d (RUNPATH)  Library runpath: [$ORIGIN/../shared_libraries/lib:$ORIGIN/../lib]
```

If this is empty or points elsewhere, `rpath-patcher.sh` didn't run during build. Rebuild the image or re-download a known-good release.

If RPATH is correct but the file still isn't found, verify `ls /opt/python/shared_libraries/lib/libssl.so*` — the file should exist. If it doesn't, the image was built incompletely.

### `ImportError: No module named '_ssl'`

The SSL extension didn't build. This is a build-time issue, not a runtime one. Rebuild with fresh logs and check the `python_builder` stage for OpenSSL headers / linker errors.

### `ssl.SSLError: [SSL: CERTIFICATE_VERIFY_FAILED]`

The shipped OpenSSL doesn't bundle CA certificates. Set an explicit CA bundle:

```bash
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt   # most Linux distros
```

Or install `certifi` via pip:

```bash
/opt/python/bin/pip3 install certifi
python3 -c "import ssl, certifi; print(certifi.where())"
```

The `requests` library will use `certifi` automatically.

### `ImportError: undefined symbol: <something>` loading a C extension

Usually a package built against a different OpenSSL / libffi / etc. than what we ship. Rebuild the package from source against this Python:

```
/opt/python/bin/pip3 install --no-binary :all: <package>
```

### `import readline` silently does nothing in the REPL

Check if readline was built: `ls /opt/python/shared_libraries/lib/libreadline.so*`. If missing, rebuild with readline enabled. Otherwise verify with:

```python
>>> import readline
>>> readline.__doc__
```

## pip

### `pip3 -m pip ...` errors with "no such option: -m"

`-m` is a Python flag, not a pip flag. Pip's own self-upgrade notice suggests this form but it's wrong in our context. Use:

```
/opt/python/bin/python3 -m pip install --upgrade pip
```

### Pip installs a wheel but `import` fails

Check if pip picked a wheel for the wrong libc. Our Python is musl-linked; pip should pick `*-musllinux_*.whl`, not `*-manylinux*.whl`. Pip does this automatically based on `sys.platform` tags, but if it got it wrong, force a source build:

```
pip install --no-binary :all: <package>
```

### Pip's SSL connection to PyPI fails

Usually missing CA certs. See [ssl.SSLError above](#sslsslerror-ssl-certificate_verify_failed).

Workaround for one-off use:

```
pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org <package>
```

(Not recommended for regular use — install `certifi` properly.)

## Building from source

### Build fails at a specific dep (e.g. `build_zlib.sh` returns 8)

Upstream URL rot. Run the script's `wget` command manually to see the HTTP status:

```
wget https://www.zlib.net/zlib-1.3.1.tar.gz
# HTTP 404 — moved to fossils/
```

Fix in the script — commonly known flaky sources:

- `zlib.net` — only keeps latest; older in `zlib.net/fossils/`
- `ftpmirror.gnu.org` — geo-redirects, can land on a 403-blocking mirror
- `tukaani.org/lzma/` — 2008-era tarball, `config.guess` doesn't know aarch64 (but we don't target aarch64)

### Build gets to `musl_builder` stage then hangs or OOMs

You're probably building under QEMU emulation (Apple Silicon → amd64). Options:

1. Build on a native x86_64 host.
2. Let CI build it.
3. Add more RAM to Docker Desktop (settings → Resources). musl-cross-make wants ~4-6 GB.

### Build completes but `docker run … file /opt/python/bin/python3` says "dynamically linked"

The launcher wasn't compiled static. Check `launcher_builder` stage logs for the `gcc -static ...` invocation. If `-static` is missing from the command, check the Dockerfile.

### `patchelf: not an ELF executable` in `rpath-patcher.sh`

`rpath-patcher.sh` filters with `file | grep 'dynamically linked'`, so static binaries (the launcher) are skipped. If you see this error, the filter probably missed a non-ELF file. Rare. Check which file triggered it.

## Debugging techniques

### Inspect the launcher's decision

Add `-x` to the launcher — wait, the launcher is C, not a shell script. So:

```bash
strace -f -e execve /opt/python/bin/python3 -c 'print(1)' 2>&1 | head -30
```

Expected sequence:

```
execve("/opt/python/bin/python3", ["python3", "-c", "print(1)"], …)       # the launcher itself
execve("/opt/python/shared_libraries/lib/ld-musl-x86_64.so.1",
       ["/opt/python/bin/python3", "--argv0", "python3",
        "/opt/python/bin/python3.12-real", "-c", "print(1)"], …)           # launcher → ld.so
```

If the second execve is missing or goes to a wrong path, the launcher had a problem.

### Inspect ELF headers

```bash
readelf -l /opt/python/bin/python3.12-real | grep -A1 INTERP
readelf -d /opt/python/bin/python3.12-real | grep -E 'NEEDED|RUNPATH|RPATH'
file /opt/python/bin/python3
file /opt/python/bin/python3.12-real
ldd  /opt/python/bin/python3.12-real
```

### Inspect what Python thinks

```python
import sys
print("executable:", sys.executable)
print("prefix:",     sys.prefix)
print("path:",       sys.path)
import ssl; print("ssl:", ssl.OPENSSL_VERSION)
```

`sys.executable` should be `…/bin/python3.X-real`. `sys.prefix` should be `/opt/python` (or wherever you installed).

### Check what files the extension imports are looking for

```bash
strace -f -e openat /opt/python/bin/python3 -c 'import ssl' 2>&1 \
  | grep -E 'libssl|libcrypto|\.so' | head -20
```

This shows which `.so` paths the dynamic linker tried, in order.

### Verify the musl symlink is in place

```bash
$ ls -la /opt/python/shared_libraries/lib/ld-musl-*.so.1
lrwxrwxrwx … ld-musl-x86_64.so.1 -> libc.so
```

If this is missing, the `rpath-patcher.sh` `ln -s libc.so ld-musl-…` step didn't run. The launcher will fail with `<path>: No such file or directory`.

## Error reference

| Error | Root cause | Fix |
|-------|------------|-----|
| `standalone-python launcher: readlink /proc/self/exe` | `/proc` not mounted | Mount `/proc` in sandbox |
| `standalone-python launcher: <path>/ld-musl-*.so.1` | Missing shipped ld-musl | Re-extract tarball; check `rpath-patcher.sh` ran |
| `standalone-python launcher: could not locate python*-real` | Missing real binary | Re-extract tarball |
| `./python3: No such file or directory` (file exists) | Broken file / wrong arch | Check `file` output, verify arch match |
| `FATAL: kernel too old` | Linux < 2.6.39 | Unsupported; use newer kernel |
| `ImportError: lib<something>.so.X: cannot open` | Wrong/missing shared lib | Check RPATH + `shared_libraries/lib/` |
| `ssl.SSLError: CERTIFICATE_VERIFY_FAILED` | No CA bundle | Set `SSL_CERT_FILE` or install `certifi` |
| `pip: no such option: -m` | Wrong invocation | Use `python3 -m pip`, not `pip3 -m pip` |
| `Illegal instruction` | Binary compiled for wrong CPU class | Check arch variant matches host |
| `patchelf: not an ELF executable` (during build) | Non-ELF file in filter | Check what file triggered it |

---

Still stuck? Open an issue with:

- Host distro + kernel (`uname -a`)
- Full output of `file /opt/python/bin/python3` and `file /opt/python/bin/python3.X-real`
- First ~30 lines of `strace -f -e execve /opt/python/bin/python3 --version 2>&1`
- The full error message
