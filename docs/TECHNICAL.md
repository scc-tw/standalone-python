# Technical Reference

Complete technical specifications and implementation details for Standalone Python.

## Table of Contents

- [Dependency Specifications](#dependency-specifications)
- [Compilation Flags](#compilation-flags)
- [File Layout Reference](#file-layout-reference)
- [Environment Variables](#environment-variables)
- [Binary Format Details](#binary-format-details)
- [Performance Characteristics](#performance-characteristics)
- [Security Specifications](#security-specifications)
- [API Reference](#api-reference)
- [System Requirements](#system-requirements)

## Dependency Specifications

### Complete Dependency Matrix

| Component | Version | Source URL | License | Build Time | Size |
|-----------|---------|------------|---------|------------|------|
| **Core Runtime** |
| musl-libc | 1.2.4 | https://musl.libc.org/ | MIT | 30-45 min | 1.2MB |
| GCC (for musl) | 13.2.0 | https://gcc.gnu.org/ | GPL | included | N/A |
| Linux headers | 6.1.36 | https://kernel.org/ | GPL | included | N/A |
| **Compression** |
| zlib | 1.3.1 | https://zlib.net/ | zlib | 5 min | 200KB |
| bzip2 | 1.0.8 | https://sourceware.org/bzip2/ | BSD | 5 min | 150KB |
| lzma | 5.4.4 | https://tukaani.org/xz/ | Public Domain | 5 min | 300KB |
| xz | 5.4.4 | https://tukaani.org/xz/ | Public Domain | 5 min | 300KB |
| **Core Libraries** |
| libffi | 3.4.4 | https://github.com/libffi/libffi | MIT | 5 min | 150KB |
| expat | 2.6.0 | https://libexpat.github.io/ | MIT | 5 min | 250KB |
| gdbm | 1.23 | https://www.gnu.org/software/gdbm/ | GPL | 5 min | 400KB |
| **Security** |
| OpenSSL | 1.1.1w | https://www.openssl.org/ | Apache 2.0 | 15 min | 3MB |
| **Database** |
| SQLite | 3.43.1 | https://sqlite.org/ | Public Domain | 10 min | 1.5MB |
| **Terminal** |
| ncurses | 6.4 | https://www.gnu.org/software/ncurses/ | MIT | 10 min | 2MB |
| readline | 8.2 | https://www.gnu.org/software/readline/ | GPL | 5 min | 500KB |
| **Internationalization** |
| gettext | 0.21.1 | https://www.gnu.org/software/gettext/ | GPL | 10 min | 2MB |
| **Scripting** |
| Tcl | 8.6.13 | https://www.tcl-lang.org/ | BSD | 10 min | 2MB |
| **Python** |
| Python | 3.12.3 | https://www.python.org/ | PSF | 20-30 min | 45MB |
| Python | 3.11.9 | https://www.python.org/ | PSF | 20-30 min | 43MB |
| Python | 3.10.14 | https://www.python.org/ | PSF | 20-30 min | 42MB |

### Dependency Build Order

```
musl-libc (provides base C library)
    ↓
zlib (compression, required by Python)
    ↓
libffi (foreign function interface)
    ↓
expat (XML parsing)
    ↓
gdbm (database support)
    ↓
lzma (compression)
    ↓
gettext (internationalization)
    ↓
ncurses (terminal handling)
    ↓
openssl (cryptography)
    ↓
readline (depends on ncurses)
    ↓
tcl (Tcl/Tk support)
    ↓
xz (compression)
    ↓
bzip2 (compression)
    ↓
sqlite3 (database)
    ↓
Python (final build)
```

## Compilation Flags

### Python Build Configuration

```bash
# Configure flags
./configure \
    --build="$gnuArch" \
    --enable-loadable-sqlite-extensions \
    --enable-optimizations \
    --enable-option-checking=fatal \
    --enable-shared \
    --with-lto \
    --with-system-expat \
    --without-ensurepip \
    --prefix="/opt/python" \
    --with-openssl-rpath=auto \
    --with-openssl=/opt/shared_libraries

# Compiler flags
CFLAGS="-O3 -fPIC -DTHREAD_STACK_SIZE=0x100000 -I/opt/shared_libraries/include"
CPPFLAGS="-I/opt/shared_libraries/include/ncurses -I/opt/shared_libraries/include"
LDFLAGS="-Wl,--strip-all -L/opt/shared_libraries/lib -lffi"

# Optimization flags
--enable-optimizations  # Profile-guided optimization
--with-lto             # Link-time optimization
```

### Musl Build Configuration

```makefile
# config.mak for musl-cross-make
TARGET = x86_64-linux-musl  # or i386-linux-musl for x86
OUTPUT = /opt/musl
GCC_VER = 13.2.0
MUSL_VER = 1.2.4
LINUX_VER = 6.1.36
COMMON_CONFIG += CC="gcc -static --static"
COMMON_CONFIG += CXX="g++ -static --static"
COMMON_CONFIG += FC="gfortran -static --static"
COMMON_CONFIG += CFLAGS="-O3 -pipe"
COMMON_CONFIG += CXXFLAGS="-O3 -pipe"
COMMON_CONFIG += LDFLAGS="-s"
```

### Dependency Compilation Flags

```bash
# Common flags for all dependencies
export CFLAGS="-O3 -fPIC"
export LDFLAGS="-Wl,--strip-all"
export PREFIX="/opt/shared_libraries"

# OpenSSL specific
./config \
    --prefix=$PREFIX \
    --openssldir=$PREFIX/ssl \
    no-shared \
    no-zlib \
    enable-egd

# SQLite specific
CFLAGS="$CFLAGS -DSQLITE_ENABLE_FTS4=1 \
    -DSQLITE_ENABLE_FTS3_PARENTHESIS=1 \
    -DSQLITE_ENABLE_JSON1=1 \
    -DSQLITE_ENABLE_RTREE=1 \
    -DSQLITE_ENABLE_FTS5=1"
```

## File Layout Reference

### Complete Directory Structure

```
opt/python/
├── bin/                           # Executables
│   ├── python                    # Wrapper script (entry point)
│   ├── python3                    # Symlink → python
│   ├── python3.12                # Symlink → python
│   ├── python3.12-real           # Actual Python binary (444 perms)
│   ├── pip                       # Pip wrapper script
│   ├── pip3                      # Symlink → pip
│   ├── pip3.12                   # Symlink → pip
│   ├── pip3.12-real              # Actual pip binary
│   ├── idle3.12                  # IDLE editor
│   ├── pydoc3.12                 # Documentation tool
│   └── 2to3-3.12                 # Python 2 to 3 converter
├── include/                       # C headers
│   └── python3.12/               # Python C API headers
│       ├── Python.h
│       ├── pyconfig.h
│       └── ...
├── lib/                          # Libraries
│   ├── python3.12/               # Python standard library
│   │   ├── __pycache__/         # Bytecode cache
│   │   ├── asyncio/             # Async I/O
│   │   ├── collections/         # Collections
│   │   ├── concurrent/          # Concurrent execution
│   │   ├── ctypes/              # C types
│   │   ├── distutils/           # Distribution utilities
│   │   ├── email/               # Email handling
│   │   ├── encodings/           # Character encodings
│   │   ├── html/                # HTML processing
│   │   ├── http/                # HTTP modules
│   │   ├── importlib/           # Import machinery
│   │   ├── json/                # JSON support
│   │   ├── lib-dynload/         # Dynamic modules
│   │   │   ├── _ssl.cpython-312-x86_64-linux-musl.so
│   │   │   ├── _sqlite3.cpython-312-x86_64-linux-musl.so
│   │   │   └── ...
│   │   ├── multiprocessing/     # Multiprocessing
│   │   ├── site-packages/       # Third-party packages
│   │   ├── sqlite3/             # SQLite interface
│   │   ├── ssl.py               # SSL module
│   │   ├── test/                # Test suite
│   │   ├── unittest/            # Unit testing
│   │   ├── urllib/              # URL handling
│   │   ├── xml/                 # XML processing
│   │   └── ...
│   ├── libpython3.12.so.1.0     # Python shared library
│   └── pkgconfig/                # Package configuration
│       └── python-3.12.pc
├── share/                        # Shared data
│   └── man/                     # Manual pages
│       └── man1/
│           ├── python3.12.1
│           └── ...
└── shared_libraries/             # Bundled dependencies
    └── lib/
        ├── libc.so               # Musl C library
        ├── libcrypto.so.1.1      # OpenSSL crypto
        ├── libssl.so.1.1         # OpenSSL SSL
        ├── libsqlite3.so.0       # SQLite
        ├── libreadline.so.8      # Readline
        ├── libncurses.so.6       # NCurses
        ├── libz.so.1             # Zlib
        ├── libbz2.so.1.0         # Bzip2
        ├── liblzma.so.5          # LZMA
        ├── libffi.so.8           # Foreign Function Interface
        ├── libexpat.so.1         # XML parsing
        └── ...
```

### File Sizes (Approximate)

| Directory | Size | Contents |
|-----------|------|----------|
| bin/ | 15MB | Executables and wrappers |
| include/ | 3MB | Header files |
| lib/python3.12/ | 35MB | Standard library |
| lib/python3.12/site-packages/ | Variable | User packages |
| shared_libraries/ | 12MB | Dependencies |
| **Total** | ~65-70MB | Complete distribution |

## Environment Variables

### Python-Specific Variables

| Variable | Purpose | Default | Set By |
|----------|---------|---------|--------|
| `PYTHONHOME` | Python installation prefix | `/opt/python` | Wrapper |
| `PYTHONPATH` | Module search paths | `lib/python3.12/site-packages` | Wrapper |
| `PYTHONDONTWRITEBYTECODE` | Disable .pyc creation | unset | User |
| `PYTHONOPTIMIZE` | Enable optimizations | unset | User |
| `PYTHONHASHSEED` | Hash randomization seed | random | Python |
| `PYTHONIOENCODING` | I/O encoding | utf-8 | Python |
| `PYTHONUNBUFFERED` | Unbuffered output | unset | User |
| `PYTHONVERBOSE` | Verbose imports | unset | User |
| `PYTHONWARNINGS` | Warning control | unset | User |

### Standalone Python Variables

| Variable | Purpose | Value |
|----------|---------|-------|
| `INSTALL_PREFIX` | Installation directory | Dynamic (from wrapper) |
| `REAL_PYTHON` | Actual Python binary | `python3.12-real` |
| `SCRIPT_DIR` | Wrapper directory | `bin/` |
| `magic_bootstraping_libc_path` | Musl interpreter location | `/tmp/StAnDaLoNeMuSlInTeRpReTeR-musl-x86_64.so` |

### System Variables

| Variable | Purpose | Impact |
|----------|---------|--------|
| `LD_LIBRARY_PATH` | Library search path | Not used (RPATH instead) |
| `PATH` | Executable search | Add `opt/python/bin` |
| `TMPDIR` | Temporary directory | Used for musl copy |
| `HOME` | User home | Used for pip cache |

## Binary Format Details

### ELF Structure

```
Python Binary (python3.12-real):
┌─────────────────────────────┐
│       ELF Header            │
├─────────────────────────────┤
│    Program Headers          │
│  - INTERP: /tmp/StAnDa*.so │
│  - LOAD: Code segment      │
│  - LOAD: Data segment      │
│  - DYNAMIC: Dynamic info   │
├─────────────────────────────┤
│    Section Headers          │
│  - .text (code)            │
│  - .data (initialized)     │
│  - .bss (uninitialized)    │
│  - .dynamic (linking info) │
└─────────────────────────────┘
```

### Dynamic Linking Information

```bash
# Interpreter path (patched)
INTERP: /tmp/StAnDaLoNeMuSlInTeRpReTeR-musl-x86_64.so

# RPATH (relative library paths)
RPATH: $ORIGIN/../shared_libraries/lib:$ORIGIN/../lib

# Required libraries
NEEDED: libpython3.12.so.1.0
NEEDED: libssl.so.1.1
NEEDED: libcrypto.so.1.1
NEEDED: libc.so (musl)
```

### Symbol Resolution

```
Symbol lookup order:
1. Binary itself (python3.12-real)
2. $ORIGIN/../shared_libraries/lib/
3. $ORIGIN/../lib/
4. Musl libc internal libraries
```

## Performance Characteristics

### Startup Performance

| Operation | Time | Details |
|-----------|------|---------|
| Wrapper execution | ~5ms | Shell script overhead |
| Musl bootstrap | ~3ms | Copy to /tmp (first run) |
| Library loading | ~10ms | Shared library resolution |
| Python initialization | ~50ms | Runtime setup |
| **Total cold start** | ~70ms | First execution |
| **Warm start** | ~20ms | Subsequent runs |

### Memory Usage

| Component | RAM Usage | Notes |
|-----------|-----------|-------|
| Base interpreter | 8MB | Minimal Python |
| Standard library | 15MB | Loaded modules |
| Shared libraries | 5MB | Mapped libraries |
| User modules | Variable | Application-specific |
| **Typical total** | 30-50MB | Running application |

### Disk I/O

| Operation | Size | Frequency |
|-----------|------|-----------|
| Musl copy to /tmp | 1.2MB | Once per boot |
| Module loading | Variable | On import |
| Bytecode cache | Variable | First import |
| Pip downloads | Variable | Package installation |

### CPU Usage

```python
# Optimization levels and impact
-O0: No optimization (default)
-O1: Basic optimization, remove assert
-O2: More optimization, remove docstrings
--with-lto: Link-time optimization (10-20% faster)
--enable-optimizations: PGO (20-30% faster)
```

## Security Specifications

### File Permissions

```bash
# Executables
-r-xr-xr-x  python-wrapper      # 755
-r--r--r--  python3.12-real     # 444 (read-only)
-r-xr-xr-x  pip-wrapper         # 755

# Libraries
-r--r--r--  *.so                # 444
-rw-r--r--  *.py                # 644
-rw-r--r--  *.pyc               # 644

# Directories
drwxr-xr-x  directories          # 755
```

### Security Features

| Feature | Status | Notes |
|---------|--------|-------|
| ASLR | Enabled | Address randomization |
| DEP/NX | Enabled | Non-executable stack |
| RELRO | Full | Read-only relocations |
| Stack Canaries | Enabled | Buffer overflow protection |
| Fortify Source | Level 2 | Compile-time protection |
| PIE | Enabled | Position independent |

### Cryptographic Support

```python
# Supported algorithms (via OpenSSL 1.1.1w)
- TLS 1.0, 1.1, 1.2, 1.3
- AES-128, AES-256
- RSA, ECDSA, EdDSA
- SHA-1, SHA-256, SHA-512
- HMAC
- PBKDF2
```

## API Reference

### Wrapper Script API

```bash
# python-wrapper functions
find_real_python()      # Locate python*-real binary
setup_environment()     # Configure PYTHONPATH/PYTHONHOME
bootstraping_libc()     # Copy musl to /tmp
invoke_real_python()    # Execute actual Python
restore_environment()   # Clean up environment
```

### Python C API Compatibility

```c
// Supported API version
#define PY_VERSION "3.12.3"
#define PY_MAJOR_VERSION 3
#define PY_MINOR_VERSION 12
#define PY_MICRO_VERSION 3

// ABI compatibility
#define Py_LIMITED_API 0x030C0000  // 3.12+
```

### Module Extension API

```python
# Building C extensions
from distutils.core import setup, Extension

module = Extension('mymodule',
    sources=['mymodule.c'],
    include_dirs=['/opt/python/include/python3.12'],
    library_dirs=['/opt/python/lib'],
    runtime_library_dirs=['/opt/python/lib'])

setup(name='MyModule',
      ext_modules=[module])
```

## System Requirements

### Minimum Requirements

| Component | Requirement | Notes |
|-----------|-------------|-------|
| **Kernel** | Linux 2.6.32+ | Musl minimum |
| **Architecture** | x86_64 or x86 | 64-bit or 32-bit |
| **Memory** | 128MB RAM | 512MB recommended |
| **Disk** | 200MB free | For installation |
| **/tmp** | 50MB free | For musl copy |
| **Shell** | POSIX sh | For wrappers |

### Supported Distributions

| Distribution | Versions | Status |
|--------------|----------|--------|
| Ubuntu | 14.04+ | ✅ Fully supported |
| Debian | 8+ | ✅ Fully supported |
| RHEL/CentOS | 6+ | ✅ Fully supported |
| Alpine | All | ✅ Fully supported |
| Arch | All | ✅ Fully supported |
| OpenSUSE | 12+ | ✅ Fully supported |
| Fedora | 20+ | ✅ Fully supported |
| Amazon Linux | All | ✅ Fully supported |
| Embedded Linux | 2.6.32+ | ✅ Fully supported |

### Container Support

| Platform | Support | Notes |
|----------|---------|-------|
| Docker | ✅ Full | All Linux images |
| Podman | ✅ Full | Rootless supported |
| LXC/LXD | ✅ Full | No restrictions |
| Kubernetes | ✅ Full | Any Linux nodes |
| OpenShift | ✅ Full | No special requirements |

### Not Supported

- Windows (including WSL1)
- macOS
- FreeBSD/OpenBSD/NetBSD
- Solaris
- AIX
- Non-Linux systems

---

*This technical reference provides comprehensive details for developers and system administrators working with Standalone Python.*