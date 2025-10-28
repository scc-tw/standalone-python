# Installation Guide

This guide walks you through downloading, installing, and verifying Standalone Python on your Linux system.

## Table of Contents

- [System Requirements](#system-requirements)
- [Quick Start](#quick-start)
- [Download](#download)
- [Installation](#installation)
- [Verification](#verification)
- [Directory Structure](#directory-structure)
- [Multiple Versions](#multiple-versions)
- [Uninstallation](#uninstallation)

## System Requirements

### Minimum Requirements

- **Operating System**: Any Linux distribution (kernel 2.6.32 or later)
- **Architecture**: x86_64 (64-bit) or x86 (32-bit)
- **Disk Space**: ~200MB per Python installation
- **RAM**: 128MB minimum (512MB recommended)
- **Temporary Space**: 50MB in `/tmp` for runtime files

### Key Features

✅ **No GLIBC dependency** - Works on any Linux regardless of libc version
✅ **No root required** - Can be installed in user space
✅ **Fully relocatable** - Move the installation anywhere
✅ **Self-contained** - All dependencies included

## Quick Start

For the impatient, here's the fastest way to get started:

```bash
# Download the latest release (Python 3.12 for x86_64)
wget https://github.com/your-repo/standalone-python/releases/latest/download/release-3.12-x86_64.tar.gz

# Extract the archive
tar -xzf release-3.12-x86_64.tar.gz

# Run Python
./opt/python/bin/python --version
```

That's it! You now have a working Python installation.

## Download

### Official Releases

Download pre-built releases from our GitHub releases page. Choose the appropriate version for your system:

#### Python 3.12 (Latest)
- [release-3.12-x86_64.tar.gz](https://github.com/your-repo/standalone-python/releases/latest) - 64-bit Linux
- [release-3.12-x86.tar.gz](https://github.com/your-repo/standalone-python/releases/latest) - 32-bit Linux

#### Python 3.11
- [release-3.11-x86_64.tar.gz](https://github.com/your-repo/standalone-python/releases/latest) - 64-bit Linux
- [release-3.11-x86.tar.gz](https://github.com/your-repo/standalone-python/releases/latest) - 32-bit Linux

#### Python 3.10
- [release-3.10-x86_64.tar.gz](https://github.com/your-repo/standalone-python/releases/latest) - 64-bit Linux
- [release-3.10-x86.tar.gz](https://github.com/your-repo/standalone-python/releases/latest) - 32-bit Linux

### Choosing the Right Version

1. **Check your architecture**:
   ```bash
   uname -m
   ```
   - `x86_64` → Use x86_64 version
   - `i386`, `i686` → Use x86 version

2. **Python version selection**:
   - **3.12** - Latest features, best performance
   - **3.11** - Stable, widely compatible
   - **3.10** - LTS, maximum compatibility

### Download via Command Line

```bash
# Using wget
wget https://github.com/your-repo/standalone-python/releases/latest/download/release-3.12-x86_64.tar.gz

# Using curl
curl -LO https://github.com/your-repo/standalone-python/releases/latest/download/release-3.12-x86_64.tar.gz
```

### Verify Download Integrity

Always verify the downloaded file:

```bash
# Check file size (should be ~50-70MB)
ls -lh release-*.tar.gz

# Extract and test
tar -tzf release-3.12-x86_64.tar.gz > /dev/null && echo "Archive OK" || echo "Archive corrupted"
```

## Installation

### Standard Installation

1. **Create installation directory** (optional):
   ```bash
   mkdir -p ~/standalone-python
   cd ~/standalone-python
   ```

2. **Extract the archive**:
   ```bash
   tar -xzf /path/to/release-3.12-x86_64.tar.gz
   ```

3. **Verify the installation**:
   ```bash
   ./opt/python/bin/python --version
   # Output: Python 3.12.3
   ```

### System-Wide Installation (requires root)

To make Standalone Python available system-wide:

```bash
# Extract to /usr/local
sudo tar -xzf release-3.12-x86_64.tar.gz -C /usr/local/

# Create symbolic links
sudo ln -s /usr/local/opt/python/bin/python /usr/local/bin/standalone-python
sudo ln -s /usr/local/opt/python/bin/pip /usr/local/bin/standalone-pip

# Test the installation
standalone-python --version
```

### User Installation (no root required)

Install in your home directory:

```bash
# Extract to home directory
cd ~
tar -xzf /path/to/release-3.12-x86_64.tar.gz

# Add to PATH (add to ~/.bashrc for persistence)
export PATH="$HOME/opt/python/bin:$PATH"

# Test the installation
python --version
```

### Custom Installation Location

You can install Standalone Python anywhere:

```bash
# Extract to custom location
mkdir -p /my/custom/path
tar -xzf release-3.12-x86_64.tar.gz -C /my/custom/path/

# Run from custom location
/my/custom/path/opt/python/bin/python --version
```

## Verification

### Basic Verification

Verify your installation is working correctly:

```bash
# Check Python version
./opt/python/bin/python --version

# Run a simple Python command
./opt/python/bin/python -c "print('Hello from Standalone Python!')"

# Check pip
./opt/python/bin/pip --version

# List installed packages
./opt/python/bin/pip list
```

### Complete Verification

Run comprehensive tests:

```bash
# Test Python interpreter
./opt/python/bin/python -c "
import sys
import platform
print(f'Python: {sys.version}')
print(f'Platform: {platform.platform()}')
print(f'Machine: {platform.machine()}')
"

# Test standard library imports
./opt/python/bin/python -c "
import os, sys, json, sqlite3, ssl, urllib.request
print('Standard library: OK')
"

# Test pip functionality
./opt/python/bin/pip list --format=json > /dev/null && echo "pip: OK"
```

### Verify Portability

Test that the installation is truly portable:

```bash
# Move the installation
mv opt /tmp/test-python

# Run from new location
/tmp/test-python/python/bin/python --version

# Move it back
mv /tmp/test-python opt
```

## Directory Structure

After extraction, you'll have the following structure:

```
opt/
└── python/
    ├── bin/                 # Executable files
    │   ├── python          # Python wrapper script
    │   ├── python3         # Symlink to python
    │   ├── python3.12-real # Actual Python binary
    │   ├── pip            # Pip wrapper script
    │   └── pip3.12-real   # Actual pip binary
    ├── include/            # Header files
    ├── lib/                # Python standard library
    │   └── python3.12/
    │       ├── site-packages/  # Installed packages
    │       └── ...
    └── shared_libraries/   # Bundled dependencies
        └── lib/
            ├── libc.so     # Musl libc
            └── ...         # Other shared libraries
```

### Important Files

- `bin/python` - Main Python executable (wrapper)
- `bin/pip` - Package installer (wrapper)
- `lib/python3.12/` - Standard library
- `lib/python3.12/site-packages/` - Installed packages location
- `shared_libraries/lib/` - All bundled dependencies

## Multiple Versions

You can install multiple Python versions side by side:

```bash
# Install Python 3.12
tar -xzf release-3.12-x86_64.tar.gz -C ~/python312/

# Install Python 3.11
tar -xzf release-3.11-x86_64.tar.gz -C ~/python311/

# Use specific versions
~/python312/opt/python/bin/python --version  # Python 3.12.3
~/python311/opt/python/bin/python --version  # Python 3.11.9
```

### Managing Multiple Versions

Create aliases for convenience:

```bash
# Add to ~/.bashrc
alias python312='~/python312/opt/python/bin/python'
alias python311='~/python311/opt/python/bin/python'
alias pip312='~/python312/opt/python/bin/pip'
alias pip311='~/python311/opt/python/bin/pip'

# Use the aliases
python312 script.py
pip312 install requests
```

## Uninstallation

Standalone Python doesn't modify your system, so uninstallation is simple:

### Remove the Installation

```bash
# Remove the extracted directory
rm -rf /path/to/opt

# If you created symbolic links
sudo rm /usr/local/bin/standalone-python
sudo rm /usr/local/bin/standalone-pip
```

### Clean Temporary Files

Standalone Python creates a temporary file for the musl interpreter:

```bash
# Remove temporary musl interpreter (recreated on next run)
rm -f /tmp/StAnDaLoNeMuSlInTeRpReTeR-musl-*.so
```

### Remove from PATH

If you added it to your PATH, remove the relevant lines from:
- `~/.bashrc`
- `~/.profile`
- `~/.bash_profile`

## Troubleshooting Installation

### Common Issues

**Archive extraction fails**
```bash
# Ensure you have enough disk space
df -h .

# Check archive integrity
tar -tzf release-*.tar.gz > /dev/null
```

**Permission denied errors**
```bash
# Ensure execute permissions
chmod +x opt/python/bin/*
```

**Wrong architecture**
```bash
# Verify your system architecture matches the download
uname -m
file opt/python/bin/python3.12-real
```

For more troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Next Steps

- Learn how to use Standalone Python: [USAGE.md](USAGE.md)
- Understand the architecture: [ARCHITECTURE.md](ARCHITECTURE.md)
- Build your own version: [BUILD.md](BUILD.md)
- Read the FAQ: [FAQ.md](FAQ.md)

---

*For additional help, please refer to our [Troubleshooting Guide](TROUBLESHOOTING.md) or open an issue on GitHub.*