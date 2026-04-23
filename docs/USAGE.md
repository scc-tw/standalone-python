# Usage Guide

Running Python and pip from a Standalone Python install, and common integration patterns.

All examples assume the install lives at `/opt/python/`. Adjust if you extracted elsewhere.

## Contents
- [Running Python](#running-python)
- [The REPL](#the-repl)
- [pip](#pip)
- [Virtual environments](#virtual-environments)
- [Environment variables](#environment-variables)
- [Shebang scripts](#shebang-scripts)
- [Integration with shell/Make/Docker/CI](#integration)
- [Common patterns](#common-patterns)

## Running Python

```bash
# Direct invocation
/opt/python/bin/python3 script.py

# With args
/opt/python/bin/python3 -c 'print(1 + 1)'
/opt/python/bin/python3 -m http.server 8000
/opt/python/bin/python3 -m venv .venv

# Via PATH
export PATH="/opt/python/bin:$PATH"
python3 --version
```

`python3`, `pip3`, `python`, and `pip` are all the same static launcher binary (with `python`/`pip` as symlinks). It dispatches to the real `pythonX.Y-real` or `pipX.Y-real` based on `argv[0]`.

## The REPL

```bash
$ /opt/python/bin/python3
Python 3.12.x (main, …) on linux
>>> import sys; sys.executable
'/opt/python/bin/python3.12-real'
>>> import ssl; ssl.OPENSSL_VERSION
'OpenSSL …'
```

`sys.executable` points at the real binary (via `/proc/self/exe` resolution), not the launcher. That's what makes subprocess-spawned Python calls work (`multiprocessing`, `concurrent.futures` with `ProcessPoolExecutor`, etc.).

## pip

```bash
# Install a package
/opt/python/bin/pip3 install requests

# Install pinned versions
/opt/python/bin/pip3 install 'requests==2.31.*'

# List installed
/opt/python/bin/pip3 list

# Upgrade pip itself — note: use python3 -m pip, NOT pip3 -m pip
/opt/python/bin/python3 -m pip install --upgrade pip
```

Pre-built wheels (numpy, pandas, cryptography, pybind11 modules, etc.) install cleanly. C extensions that compile from source also work as long as the usual build-time prerequisites (gcc, headers, etc.) are available on the host.

> **About pip's "how to upgrade" notice.** Pip emits `/opt/python/bin/pip3 -m pip install --upgrade pip` as its suggested upgrade command, but `-m` is a Python flag, not a pip flag — routing it through `pip3` will error with `no such option: -m`. Use `python3 -m pip install --upgrade pip` instead.

## Virtual environments

Standard `venv`:

```bash
/opt/python/bin/python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
deactivate
```

The venv's `bin/python` is a symlink or small shim that ultimately delegates to the launcher. The venv's `pip` installs packages into `.venv/lib/pythonX.Y/site-packages/` as usual.

Site-packages inside the main install (`/opt/python/lib/python3.12/site-packages/`) is writable if you extracted as root; venvs are the recommended way to isolate projects regardless.

## Environment variables

You generally don't need to set anything. The launcher sets `PYTHONHOME` to the install prefix if it isn't already set; everything else derives from `sys.executable`.

Useful overrides:

| Variable | Effect |
|----------|--------|
| `PYTHONHOME` | Override the prefix auto-derived from `/proc/self/exe`. Rarely needed. |
| `PYTHONPATH` | Extra directories on `sys.path`, same semantics as upstream CPython. |
| `PYTHONDONTWRITEBYTECODE=1` | Don't create `.pyc` files. |
| `PYTHONUNBUFFERED=1` | Force unbuffered stdout/stderr. |
| `SSL_CERT_FILE` / `SSL_CERT_DIR` | Point `ssl` at a custom CA bundle. The shipped OpenSSL doesn't bundle certificates — for HTTPS against public hosts, either install `certifi` via pip or point these at your system bundle (`/etc/ssl/certs/ca-certificates.crt` on most distros). |

## Shebang scripts

`/opt/python/bin/python3` works as a shebang target on any system that can find it:

```python
#!/opt/python/bin/python3
print("hello")
```

For relocatable scripts, use `/usr/bin/env`:

```python
#!/usr/bin/env python3
```

…after ensuring `/opt/python/bin` is in the invoking shell's `PATH`.

## Integration

### In a shell script

```bash
#!/bin/bash
PY=/opt/python/bin/python3
"$PY" -c 'import json,sys; json.dump({"v":sys.version},sys.stdout)'
```

### In a Makefile

```makefile
PY := /opt/python/bin/python3
PIP := /opt/python/bin/pip3

install:
	$(PIP) install -r requirements.txt

test:
	$(PY) -m pytest
```

### In a Dockerfile (multi-stage)

```dockerfile
FROM debian:bookworm-slim
COPY --from=standalone-python:3.12-x86_64 /opt/python /opt/python
ENV PATH="/opt/python/bin:${PATH}"

RUN python3 -m pip install flask
COPY app.py /
CMD ["python3", "/app.py"]
```

Note you don't need `apt install python3` or `apt install libssl3` — the shipped tree is self-sufficient.

### In CI (GitHub Actions)

```yaml
- name: Download standalone-python
  run: |
    curl -L -o py.tar.gz "https://github.com/25077667/standalone-python/releases/latest/download/release-3.12-x86_64.tar.gz"
    sudo tar -xzf py.tar.gz -C /
- name: Run tests
  run: /opt/python/bin/python3 -m pytest
```

### In cron

```
0 * * * * /opt/python/bin/python3 /opt/jobs/hourly.py
```

No `source venv/bin/activate` dance needed unless you're using venvs.

## Common patterns

**Pinning to this Python in a project:**

```bash
# project/.envrc (for direnv)
export PATH=/opt/python/bin:$PATH
```

**One-shot script with deps:**

```bash
/opt/python/bin/python3 -m venv /tmp/job && \
  /tmp/job/bin/pip install requests && \
  /tmp/job/bin/python -c 'import requests; print(requests.get("https://example.com").status_code)'
```

**Checking OpenSSL version without running Python:**

```bash
strings /opt/python/shared_libraries/lib/libssl.so.3 | grep -m1 '^OpenSSL '
```

**Identifying which real binary backs the launcher:**

```bash
$ ls /opt/python/bin/python*-real
/opt/python/bin/python3.12-real
```

---

For installation, see [INSTALLATION.md](INSTALLATION.md). For when things break, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
