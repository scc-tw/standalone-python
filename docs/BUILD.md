# Build Instructions

Complete guide for building Standalone Python from source, including all dependencies and customization options.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Build](#quick-build)
- [Build Process Overview](#build-process-overview)
- [Building Specific Versions](#building-specific-versions)
- [Dependency Management](#dependency-management)
- [Customization](#customization)
- [Build Optimization](#build-optimization)
- [Testing Your Build](#testing-your-build)
- [Troubleshooting Builds](#troubleshooting-builds)
- [Advanced Topics](#advanced-topics)

## Prerequisites

### System Requirements

- **Operating System**: Linux (build host)
- **Docker**: Version 20.10 or later
- **Disk Space**: At least 10GB free
- **RAM**: Minimum 4GB (8GB recommended)
- **CPU**: Multi-core recommended for faster builds

### Required Tools

```bash
# Install Docker (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install docker.io docker-compose

# Install build essentials
sudo apt-get install git make wget tar gzip

# Verify Docker installation
docker --version
docker run hello-world
```

### Optional Tools

```bash
# For build monitoring
sudo apt-get install htop iotop

# For log analysis
sudo apt-get install less grep awk sed
```

## Quick Build

### Fastest Build (Single Version)

```bash
# Clone the repository
git clone https://github.com/your-repo/standalone-python.git
cd standalone-python

# Build Python 3.12 for x86_64
docker build -t standalone-python:3.12-x86_64 ./3.12/x86_64/

# Extract the built Python
docker run --rm -v $(pwd):/output standalone-python:3.12-x86_64 \
    sh -c "cd /opt && tar -czf /output/python-3.12-x86_64.tar.gz python"
```

## Build Process Overview

### Important Note About Build Logs

> **📝 Pro Tip from Experience**: When building this project, the compilation logs can be enormous—we're talking gigabytes of output across all the dependency builds. You'll want to redirect everything to log files using standard Unix tools. For example, `docker build ... 2>&1 | tee build.log` will capture both stdout and stderr while still showing progress. Trust me, you'll thank yourself later when debugging build issues. The logs from building musl-libc alone can exceed 500MB, and that's just one component! Keep those log files organized by component and timestamp—you'll need them when something inevitably goes sideways during a dependency update.

### Managing Build Output

```bash
# Create a logs directory
mkdir -p build-logs

# Build with comprehensive logging
docker build -t standalone-python:3.12-x86_64 ./3.12/x86_64/ \
    2>&1 | tee build-logs/build-$(date +%Y%m%d-%H%M%S).log

# Split logs by component (useful for debugging)
docker build -t standalone-python:3.12-x86_64 ./3.12/x86_64/ \
    2>&1 | awk '/Building.*/{close(f); f="build-logs/"$2".log"} {print > f}'

# Monitor build progress without flooding terminal
docker build -t standalone-python:3.12-x86_64 ./3.12/x86_64/ \
    2>&1 | grep -E "^Step |Successfully built|ERROR"

# Compress logs after build
gzip build-logs/*.log
```

### Build Stages Explained

The build process consists of 16+ Docker stages:

```
1. base_builder     - Alpine Linux setup
2. musl_builder     - Musl libc toolchain (30-45 min)
3. libz_builder     - Zlib compression (5 min)
4. ffi_builder      - Foreign function interface (5 min)
5. expat_builder    - XML parsing (5 min)
6. gdbm_builder     - GNU database (5 min)
7. lzma_builder     - LZMA compression (5 min)
8. gettext_builder  - Internationalization (10 min)
9. ncurses_builder  - Terminal handling (10 min)
10. openssl_builder - SSL/TLS support (15 min)
11. readline_builder- Command-line editing (5 min)
12. tcl_builder     - Tcl support (10 min)
13. xz_builder      - XZ compression (5 min)
14. bzip2_builder   - Bzip2 compression (5 min)
15. sqlite3_builder - SQLite database (10 min)
16. python_builder  - Python interpreter (20-30 min)
17. patch_stage     - ELF patching (5 min)
18. final           - Package assembly (2 min)
```

**Total build time**: 2-3 hours (depending on hardware)

## Building Specific Versions

### Python 3.12

```bash
# x86_64 (64-bit)
cd standalone-python
docker build -t standalone-python:3.12-x86_64 \
    --build-arg PYTHON_VERSION=3.12.3 \
    ./3.12/x86_64/

# x86 (32-bit)
docker build -t standalone-python:3.12-x86 \
    --build-arg PYTHON_VERSION=3.12.3 \
    ./3.12/x86/
```

### Python 3.11

```bash
# x86_64 (64-bit)
docker build -t standalone-python:3.11-x86_64 \
    --build-arg PYTHON_VERSION=3.11.9 \
    ./3.11/x86_64/

# x86 (32-bit)
docker build -t standalone-python:3.11-x86 \
    --build-arg PYTHON_VERSION=3.11.9 \
    ./3.11/x86/
```

### Python 3.10

```bash
# x86_64 (64-bit)
docker build -t standalone-python:3.10-x86_64 \
    --build-arg PYTHON_VERSION=3.10.14 \
    ./3.10/x86_64/

# x86 (32-bit)
docker build -t standalone-python:3.10-x86 \
    --build-arg PYTHON_VERSION=3.10.14 \
    ./3.10/x86/
```

### Build All Versions

```bash
#!/bin/bash
# build-all.sh

VERSIONS=("3.10" "3.11" "3.12")
ARCHITECTURES=("x86_64" "x86")

for version in "${VERSIONS[@]}"; do
    for arch in "${ARCHITECTURES[@]}"; do
        echo "Building Python $version for $arch..."
        docker build -t standalone-python:${version}-${arch} \
            ./${version}/${arch}/ \
            2>&1 | tee build-logs/build-${version}-${arch}.log
    done
done
```

## Dependency Management

### Dependency Versions

Current dependency versions (as of October 2024):

| Dependency | Version | Source |
|------------|---------|--------|
| musl-libc | 1.2.4 | musl-cross-make |
| gcc | 13.2.0 | musl-cross-make |
| zlib | 1.3.1 | zlib.net |
| libffi | 3.4.4 | github.com/libffi |
| expat | 2.6.0 | github.com/libexpat |
| openssl | 1.1.1w | openssl.org |
| sqlite | 3.43.1 | sqlite.org |
| readline | 8.2 | gnu.org |
| ncurses | 6.4 | gnu.org |

### Updating Dependencies

To update a dependency version:

1. **Edit the build script**:
```bash
# Example: Update OpenSSL in 3.12/x86_64/deplib/build_openssl.sh
OPENSSL_VERSION="1.1.1w"  # Change this
wget "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
```

2. **Test the build**:
```bash
docker build --no-cache -t test-build ./3.12/x86_64/
```

3. **Verify functionality**:
```bash
docker run --rm test-build /opt/python/bin/python -c "import ssl; print(ssl.OPENSSL_VERSION)"
```

### Adding New Dependencies

Create a new build script in `deplib/`:

```bash
#!/bin/sh
# deplib/build_newlib.sh

NEWLIB_VERSION="1.0.0"
wget "https://example.com/newlib-${NEWLIB_VERSION}.tar.gz"
tar -xzf newlib-${NEWLIB_VERSION}.tar.gz
cd newlib-${NEWLIB_VERSION}

./configure \
    --prefix=/opt/shared_libraries \
    --enable-static \
    --disable-shared

make -j$(nproc)
make install
```

Update the Dockerfile:

```dockerfile
# Add new build stage
FROM previous_builder as newlib_builder
COPY ["./deplib/build_newlib.sh", "."]
RUN set -eux && ./build_newlib.sh
```

## Customization

### Python Configuration Options

Modify `deplib/build_python.sh` for custom Python builds:

```bash
# Enable additional modules
./configure \
    --enable-loadable-sqlite-extensions \
    --enable-optimizations \
    --enable-ipv6 \
    --with-computed-gotos \
    --with-lto \
    --with-system-expat \
    --with-system-ffi \
    --with-openssl=/opt/shared_libraries
```

### Optimization Flags

Adjust compilation flags for performance or size:

```bash
# For maximum performance
export CFLAGS="-O3 -march=native -mtune=native"
export LDFLAGS="-Wl,-O2 -Wl,--strip-all"

# For minimum size
export CFLAGS="-Os -ffunction-sections -fdata-sections"
export LDFLAGS="-Wl,--gc-sections -Wl,--strip-all"
```

### Removing Unnecessary Modules

Strip unwanted Python modules to reduce size:

```bash
# In the Dockerfile, after Python installation
RUN rm -rf /opt/python/lib/python3.12/test \
           /opt/python/lib/python3.12/unittest \
           /opt/python/lib/python3.12/distutils/tests \
           /opt/python/lib/python3.12/idlelib \
           /opt/python/lib/python3.12/tkinter
```

## Build Optimization

### Parallel Building

Use Docker BuildKit for improved performance:

```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1

# Build with BuildKit
docker build --progress=plain -t standalone-python:3.12-x86_64 ./3.12/x86_64/
```

### Build Caching

Leverage Docker layer caching:

```bash
# Build base layers first
docker build --target musl_builder -t musl-cache ./3.12/x86_64/

# Use cached layers for subsequent builds
docker build --cache-from musl-cache -t standalone-python:3.12-x86_64 ./3.12/x86_64/
```

### Resource Limits

Control build resource usage:

```bash
# Limit CPU usage
docker build --cpus="2.0" -t standalone-python:3.12-x86_64 ./3.12/x86_64/

# Limit memory usage
docker build --memory="4g" -t standalone-python:3.12-x86_64 ./3.12/x86_64/
```

## Testing Your Build

### Basic Tests

```bash
# Test Python execution
docker run --rm standalone-python:3.12-x86_64 \
    /opt/python/bin/python --version

# Test standard library
docker run --rm standalone-python:3.12-x86_64 \
    /opt/python/bin/python -c "import sys, os, json, sqlite3, ssl"

# Test pip
docker run --rm standalone-python:3.12-x86_64 \
    /opt/python/bin/pip --version
```

### Comprehensive Testing

Create a test script:

```python
# test_build.py
import sys
import platform
import ssl
import sqlite3
import json
import zlib
import readline
import curses

print(f"Python: {sys.version}")
print(f"Platform: {platform.platform()}")
print(f"SSL: {ssl.OPENSSL_VERSION}")
print(f"SQLite: {sqlite3.sqlite_version}")
print("All modules loaded successfully!")
```

Run the test:

```bash
docker run --rm -v $(pwd)/test_build.py:/test.py \
    standalone-python:3.12-x86_64 \
    /opt/python/bin/python /test.py
```

### Extraction Test

```bash
# Extract and test outside Docker
docker run --rm standalone-python:3.12-x86_64 \
    tar -czf - -C /opt python | tar -xzf -

# Test extracted Python
./python/bin/python --version
```

## Troubleshooting Builds

### Common Build Issues

**Issue: Build fails at musl stage**
```bash
# Solution: Increase Docker memory
docker system prune -a  # Clean up space
# Restart Docker daemon with more memory
```

**Issue: Network timeouts during downloads**
```bash
# Solution: Add retry logic to build scripts
wget --retry-connrefused --waitretry=1 --read-timeout=20 \
     --timeout=15 -t 5 <URL>
```

**Issue: Out of disk space**
```bash
# Solution: Clean Docker artifacts
docker system df  # Check usage
docker builder prune -a  # Clean build cache
docker image prune -a  # Remove unused images
```

### Debug Techniques

**Interactive debugging**:
```bash
# Start container at specific stage
docker run -it --rm standalone-python:3.12-x86_64 /bin/sh

# Debug within container
cd /src
./build_python.sh
```

**Build specific stages**:
```bash
# Build only up to Python stage
docker build --target python_builder -t debug-python ./3.12/x86_64/
```

**Verbose output**:
```bash
# Add set -x to build scripts for debugging
sed -i '2i set -x' 3.12/x86_64/deplib/*.sh
```

## Advanced Topics

### Cross-Compilation

Build for different architectures:

```bash
# Use QEMU for cross-compilation
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Build for ARM
docker buildx build --platform linux/arm64 \
    -t standalone-python:3.12-arm64 ./3.12/x86_64/
```

### Custom Base Images

Use different base distributions:

```dockerfile
# Use Debian instead of Alpine
FROM debian:bullseye-slim as base_builder
# Adjust package installation commands accordingly
```

### CI/CD Integration

Integrate with GitHub Actions:

```yaml
name: Build Standalone Python
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python: ["3.10", "3.11", "3.12"]
        arch: ["x86_64", "x86"]

    steps:
      - uses: actions/checkout@v3

      - name: Build Python ${{ matrix.python }}-${{ matrix.arch }}
        run: |
          docker build -t test:${{ matrix.python }}-${{ matrix.arch }} \
            ./${{ matrix.python }}/${{ matrix.arch }}/

      - name: Test Build
        run: |
          docker run --rm test:${{ matrix.python }}-${{ matrix.arch }} \
            /opt/python/bin/python --version
```

### Performance Profiling

Profile the build process:

```bash
# Time each stage
docker build -t standalone-python:3.12-x86_64 ./3.12/x86_64/ \
    2>&1 | ts '[%Y-%m-%d %H:%M:%S]' | tee build-profile.log

# Analyze build times
grep "Successfully built" build-profile.log | \
    awk '{print $1, $2, $NF}'
```

### Security Hardening

Add security scanning to builds:

```bash
# Scan for vulnerabilities
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy image standalone-python:3.12-x86_64
```

## Build Artifacts

### Packaging the Build

```bash
#!/bin/bash
# package.sh

VERSION="3.12"
ARCH="x86_64"
DATE=$(date +%Y%m%d)

# Extract from Docker
docker run --rm standalone-python:${VERSION}-${ARCH} \
    tar -czf - -C /opt python > \
    standalone-python-${VERSION}-${ARCH}-${DATE}.tar.gz

# Create checksum
sha256sum standalone-python-${VERSION}-${ARCH}-${DATE}.tar.gz > \
    standalone-python-${VERSION}-${ARCH}-${DATE}.tar.gz.sha256

# Verify package
tar -tzf standalone-python-${VERSION}-${ARCH}-${DATE}.tar.gz | head
```

## Next Steps

- Test your build: [USAGE.md](USAGE.md)
- Understand the architecture: [ARCHITECTURE.md](ARCHITECTURE.md)
- Set up CI/CD: [CI_CD.md](CI_CD.md)
- Contribute improvements: [CONTRIBUTING.md](CONTRIBUTING.md)

---

*Remember: Building from source gives you complete control over the Python distribution, but always test thoroughly before deploying to production.*