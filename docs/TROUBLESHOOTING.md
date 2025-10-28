# Troubleshooting Guide

Solutions to common problems when using, building, or deploying Standalone Python.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Runtime Errors](#runtime-errors)
- [Build Problems](#build-problems)
- [Package Management Issues](#package-management-issues)
- [Performance Issues](#performance-issues)
- [Compatibility Problems](#compatibility-problems)
- [Environment Issues](#environment-issues)
- [Debugging Techniques](#debugging-techniques)
- [Getting Help](#getting-help)

## Installation Issues

### Problem: Archive Extraction Fails

**Symptoms**:
```bash
tar: Error is not recoverable: exiting now
gzip: stdin: unexpected end of file
```

**Solutions**:

1. **Verify download integrity**:
```bash
# Check file size
ls -lh release-*.tar.gz

# Test archive
tar -tzf release-3.12-x86_64.tar.gz > /dev/null
echo $?  # Should be 0
```

2. **Re-download with resume**:
```bash
wget -c https://github.com/your-repo/standalone-python/releases/latest/download/release-3.12-x86_64.tar.gz
```

3. **Check disk space**:
```bash
df -h .
# Need at least 300MB free
```

### Problem: Wrong Architecture Error

**Symptoms**:
```bash
./opt/python/bin/python: cannot execute binary file: Exec format error
```

**Solutions**:

1. **Verify system architecture**:
```bash
uname -m
# x86_64 = use x86_64 version
# i386/i686 = use x86 version
```

2. **Check binary architecture**:
```bash
file opt/python/bin/python3.12-real
# Should match your system
```

3. **Download correct version**:
```bash
# For 32-bit systems
wget .../release-3.12-x86.tar.gz
```

### Problem: Permission Denied

**Symptoms**:
```bash
-bash: ./opt/python/bin/python: Permission denied
```

**Solutions**:

```bash
# Fix permissions
chmod +x opt/python/bin/*
chmod 755 opt/python/bin/python*
chmod 755 opt/python/bin/pip*

# If SELinux is enforcing
setenforce 0  # Temporary
# Or add proper context
chcon -t bin_t opt/python/bin/*
```

## Runtime Errors

### Problem: Musl Interpreter Not Found

**Symptoms**:
```bash
/bin/sh: /tmp/StAnDaLoNeMuSlInTeRpReTeR-musl-x86_64.so: not found
```

**Solutions**:

1. **Check /tmp permissions**:
```bash
ls -ld /tmp
# Should be: drwxrwxrwt

# Fix if needed
sudo chmod 1777 /tmp
```

2. **Verify musl file exists**:
```bash
ls -la opt/python/shared_libraries/lib/libc.so
# Should exist

# Manual copy if wrapper fails
cp opt/python/shared_libraries/lib/libc.so \
   /tmp/StAnDaLoNeMuSlInTeRpReTeR-musl-x86_64.so
```

3. **Use alternative location**:
```bash
# Modify wrapper to use home directory
export MUSL_PATH="$HOME/.cache/standalone-python/musl.so"
mkdir -p "$(dirname "$MUSL_PATH")"
cp opt/python/shared_libraries/lib/libc.so "$MUSL_PATH"
```

### Problem: Library Not Found

**Symptoms**:
```python
ImportError: libssl.so.1.1: cannot open shared object file
```

**Solutions**:

1. **Verify library exists**:
```bash
find opt/python -name "libssl.so*"
```

2. **Check library path**:
```bash
# Set library path explicitly
export LD_LIBRARY_PATH="$(pwd)/opt/python/shared_libraries/lib:$LD_LIBRARY_PATH"
./opt/python/bin/python
```

3. **Inspect binary RPATH**:
```bash
readelf -d opt/python/bin/python3.12-real | grep RPATH
# Should show $ORIGIN paths
```

### Problem: Module Import Errors

**Symptoms**:
```python
ModuleNotFoundError: No module named '_ssl'
```

**Solutions**:

1. **Verify module files**:
```bash
find opt/python -name "_ssl*"
# Should find _ssl.cpython-312-x86_64-linux-musl.so
```

2. **Check Python path**:
```python
import sys
print(sys.path)
# Should include site-packages
```

3. **Rebuild module cache**:
```bash
./opt/python/bin/python -m compileall opt/python/lib/
```

## Build Problems

### Problem: Docker Build Fails

**Symptoms**:
```
ERROR: failed to solve: executor failed running [/bin/sh -c ./build_musl.sh]
```

**Solutions**:

1. **Increase Docker resources**:
```bash
# Check current limits
docker system df
docker info | grep -i memory

# Increase via Docker Desktop settings
# Or restart daemon with:
sudo systemctl restart docker
```

2. **Clean Docker cache**:
```bash
docker system prune -a --volumes
docker builder prune
```

3. **Build with no cache**:
```bash
docker build --no-cache -t test ./3.12/x86_64/
```

### Problem: Network Timeouts

**Symptoms**:
```
wget: download timed out
ERROR: Service 'builder' failed to build
```

**Solutions**:

1. **Add retry logic**:
```bash
# Edit build scripts
wget --retry-connrefused --waitretry=1 \
     --read-timeout=20 --timeout=15 -t 5 \
     <URL>
```

2. **Use proxy if behind firewall**:
```dockerfile
# In Dockerfile
ARG HTTP_PROXY
ARG HTTPS_PROXY
ENV HTTP_PROXY=$HTTP_PROXY
ENV HTTPS_PROXY=$HTTPS_PROXY
```

3. **Use mirror sites**:
```bash
# Example: Use kernel.org mirror
wget https://mirrors.kernel.org/gnu/readline/readline-8.2.tar.gz
```

### Problem: Out of Disk Space

**Symptoms**:
```
No space left on device
```

**Solutions**:

1. **Check and clean space**:
```bash
df -h
docker system df
docker system prune -a --volumes
```

2. **Use external volume**:
```bash
# Mount external storage
docker run -v /mnt/external:/build ...
```

3. **Build in stages and clean**:
```bash
# Build and extract immediately
docker build --target python_builder -t temp .
docker run --rm temp tar czf - /opt/python > python.tar.gz
docker rmi temp
```

## Package Management Issues

### Problem: Pip Install Fails

**Symptoms**:
```
ERROR: Could not find a version that satisfies the requirement
```

**Solutions**:

1. **Update pip**:
```bash
./opt/python/bin/python -m pip install --upgrade pip
```

2. **Check Python version compatibility**:
```bash
./opt/python/bin/python --version
# Some packages require specific Python versions
```

3. **Use compatible versions**:
```bash
# Install specific version
./opt/python/bin/pip install 'package==1.2.3'

# Check available versions
./opt/python/bin/pip index versions package
```

### Problem: SSL Certificate Errors

**Symptoms**:
```
SSL: CERTIFICATE_VERIFY_FAILED
```

**Solutions**:

1. **Update certificates**:
```bash
./opt/python/bin/pip install --upgrade certifi
```

2. **Use trusted host (temporary)**:
```bash
./opt/python/bin/pip install --trusted-host pypi.org \
    --trusted-host files.pythonhosted.org package
```

3. **Set certificate bundle**:
```bash
export SSL_CERT_FILE=/path/to/cacert.pem
export REQUESTS_CA_BUNDLE=/path/to/cacert.pem
```

## Performance Issues

### Problem: Slow Startup

**Symptoms**:
- Python takes several seconds to start
- Simple scripts run slowly

**Solutions**:

1. **Skip bytecode generation**:
```bash
export PYTHONDONTWRITEBYTECODE=1
./opt/python/bin/python script.py
```

2. **Use optimization flags**:
```bash
./opt/python/bin/python -O script.py  # Basic optimization
./opt/python/bin/python -OO script.py # Maximum optimization
```

3. **Pre-compile modules**:
```bash
./opt/python/bin/python -m compileall -j 0 opt/python/lib/
```

### Problem: High Memory Usage

**Symptoms**:
- Memory consumption higher than expected
- Out of memory errors

**Solutions**:

1. **Monitor memory usage**:
```python
import resource
# Set memory limit (in bytes)
resource.setrlimit(resource.RLIMIT_AS, (2 * 1024**3, -1))  # 2GB
```

2. **Garbage collection tuning**:
```python
import gc
gc.collect()  # Force collection
gc.set_threshold(700, 10, 10)  # Adjust thresholds
```

3. **Use memory profiling**:
```bash
./opt/python/bin/pip install memory_profiler
./opt/python/bin/python -m memory_profiler script.py
```

## Compatibility Problems

### Problem: GLIBC Version Mismatch

**Symptoms**:
```
version `GLIBC_2.28' not found
```

**This should not happen with Standalone Python!** If it does:

**Solutions**:

1. **Verify you're using Standalone Python**:
```bash
ldd opt/python/bin/python3.12-real
# Should NOT show system libc
```

2. **Check musl is being used**:
```bash
strings opt/python/bin/python3.12-real | grep musl
# Should find musl references
```

3. **Re-extract the archive**:
```bash
# May be corrupted installation
rm -rf opt/
tar -xzf release-*.tar.gz
```

### Problem: Kernel Too Old

**Symptoms**:
```
FATAL: kernel too old
```

**Solutions**:

1. **Check kernel version**:
```bash
uname -r
# Need 2.6.32 or later
```

2. **Use older Python version**:
```bash
# Python 3.10 may have better compatibility
wget .../release-3.10-x86_64.tar.gz
```

3. **Build with older kernel headers**:
```dockerfile
# In Dockerfile, use older headers
ENV LINUX_VER=4.19.88  # Instead of 6.1.36
```

## Environment Issues

### Problem: Wrong Python Version Runs

**Symptoms**:
- System Python runs instead of Standalone Python
- Version mismatch

**Solutions**:

1. **Use absolute path**:
```bash
/full/path/to/opt/python/bin/python script.py
```

2. **Fix PATH order**:
```bash
export PATH="/path/to/opt/python/bin:$PATH"
which python  # Should show Standalone Python
```

3. **Create unique alias**:
```bash
alias spy='/path/to/opt/python/bin/python'
spy script.py
```

### Problem: Environment Variables Not Set

**Symptoms**:
```python
sys.prefix shows wrong path
PYTHONHOME not set correctly
```

**Solutions**:

1. **Check wrapper execution**:
```bash
# Make sure using wrapper, not -real binary
ls -la opt/python/bin/python
# Should be wrapper script, not symlink to -real
```

2. **Set manually if needed**:
```bash
export PYTHONHOME=/path/to/opt/python
export PYTHONPATH=/path/to/opt/python/lib/python3.12/site-packages
```

3. **Debug wrapper**:
```bash
sh -x opt/python/bin/python --version
# Shows each command executed
```

## Debugging Techniques

### Enable Verbose Output

```bash
# Python verbose mode
./opt/python/bin/python -v script.py

# Very verbose (trace imports)
./opt/python/bin/python -vv script.py

# Debug wrapper scripts
sh -x ./opt/python/bin/python script.py

# Trace system calls
strace ./opt/python/bin/python script.py 2>&1 | grep open
```

### Check Binary Details

```bash
# Interpreter path
readelf -l opt/python/bin/python3.12-real | grep interpreter

# Dynamic libraries
ldd opt/python/bin/python3.12-real

# RPATH settings
readelf -d opt/python/bin/python3.12-real | grep -E 'RPATH|RUNPATH'

# File type
file opt/python/bin/python3.12-real
```

### Python Debugging

```python
# Check paths
import sys
print("Executable:", sys.executable)
print("Prefix:", sys.prefix)
print("Path:", sys.path)

# Check modules
import sysconfig
print(sysconfig.get_paths())

# Check SSL
import ssl
print(ssl.OPENSSL_VERSION)
```

### System Information

```bash
# System details
uname -a
lsb_release -a

# Library availability
ldconfig -p | grep -E 'ssl|crypto|python'

# SELinux status
getenforce

# AppArmor status
aa-status
```

## Common Error Messages

### Reference Table

| Error | Cause | Solution |
|-------|-------|----------|
| `Exec format error` | Wrong architecture | Download correct version |
| `No such file or directory` | Missing interpreter | Check musl in /tmp |
| `Permission denied` | No execute permission | chmod +x |
| `version GLIBC not found` | Using system libc | Verify Standalone Python |
| `ImportError: No module` | Missing Python module | Check lib directory |
| `SSL: CERTIFICATE_VERIFY_FAILED` | Certificate issues | Update certificates |
| `OSError: [Errno 28]` | No space left | Clean disk space |
| `cannot allocate memory` | Out of memory | Increase RAM/swap |

## Getting Help

### Before Asking for Help

1. **Check documentation**:
   - Read relevant sections in docs/
   - Search existing issues on GitHub

2. **Gather information**:
```bash
# System info
uname -a > debug-info.txt
./opt/python/bin/python --version >> debug-info.txt

# Error details
./opt/python/bin/python script.py 2>&1 | tee -a debug-info.txt

# Directory structure
ls -la opt/python/bin/ >> debug-info.txt
```

3. **Try common fixes**:
   - Re-extract archive
   - Fix permissions
   - Check disk space
   - Restart with clean environment

### Where to Get Help

1. **GitHub Issues**: Report bugs and request features
2. **Discussions**: Ask questions and share solutions
3. **Stack Overflow**: Tag with `standalone-python`
4. **Community Forums**: Linux distribution forums

### Reporting Bugs

Include in your bug report:

1. **Environment**:
   - OS and version
   - Kernel version
   - Architecture

2. **Steps to reproduce**:
   - Exact commands run
   - Expected behavior
   - Actual behavior

3. **Error messages**:
   - Complete error output
   - Relevant log files

4. **What you've tried**:
   - Solutions attempted
   - Results of debugging

---

*If you've found a solution not listed here, please contribute it back to help others! See [CONTRIBUTING.md](CONTRIBUTING.md) for how to improve the documentation.*