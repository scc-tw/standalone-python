# Frequently Asked Questions

Common questions about Standalone Python with detailed answers.

## Table of Contents

- [General Questions](#general-questions)
- [Installation & Usage](#installation--usage)
- [Technical Questions](#technical-questions)
- [Comparison with Alternatives](#comparison-with-alternatives)
- [Build & Development](#build--development)
- [Troubleshooting](#troubleshooting)
- [Performance & Security](#performance--security)

## General Questions

### What is Standalone Python?

Standalone Python is a portable Python distribution that runs on any Linux system without requiring glibc or other system dependencies. It bundles Python with musl libc and all necessary libraries, creating a completely self-contained Python environment.

### Why was Standalone Python created?

Many environments have incompatible or outdated glibc versions that prevent running modern Python. Standalone Python solves this by:
- Eliminating glibc dependency completely
- Working on legacy systems (kernel 2.6.32+)
- Running in restricted environments
- Providing consistent Python across all Linux systems

### Who should use Standalone Python?

Standalone Python is ideal for:
- **System administrators** managing legacy systems
- **DevOps engineers** needing consistent Python across environments
- **Embedded developers** working with limited systems
- **Researchers** using HPC clusters with outdated libraries
- **Anyone** dealing with glibc compatibility issues

### Is Standalone Python production-ready?

Yes! Standalone Python is suitable for production use:
- Thoroughly tested across multiple distributions
- Used in enterprise environments
- Regular security updates
- Complete Python standard library included
- Full pip support for package installation

### What Python versions are supported?

Currently supported versions:
- Python 3.12.3 (latest features)
- Python 3.11.9 (stable)
- Python 3.10.14 (LTS)

Each version is available for both x86_64 and x86 architectures.

## Installation & Usage

### How do I install Standalone Python?

Simple three-step process:
```bash
# 1. Download
wget https://github.com/your-repo/standalone-python/releases/latest/download/release-3.12-x86_64.tar.gz

# 2. Extract
tar -xzf release-3.12-x86_64.tar.gz

# 3. Run
./opt/python/bin/python --version
```

### Can I install it system-wide?

Yes, with root access:
```bash
sudo tar -xzf release-3.12-x86_64.tar.gz -C /usr/local/
sudo ln -s /usr/local/opt/python/bin/python /usr/local/bin/standalone-python
```

### How do I use pip with Standalone Python?

Pip works just like regular Python:
```bash
# Install packages
./opt/python/bin/pip install requests numpy pandas

# Upgrade pip itself
./opt/python/bin/pip install --upgrade pip

# Install from requirements
./opt/python/bin/pip install -r requirements.txt
```

### Can I create virtual environments?

Yes, venv works normally:
```bash
./opt/python/bin/python -m venv myenv
source myenv/bin/activate
pip install flask
```

### How do I make it my default Python?

Add to your shell configuration:
```bash
# In ~/.bashrc or ~/.zshrc
export PATH="/path/to/opt/python/bin:$PATH"
alias python='/path/to/opt/python/bin/python'
alias pip='/path/to/opt/python/bin/pip'
```

## Technical Questions

### How does Standalone Python achieve portability?

Standalone Python uses several techniques:
1. **Musl libc** instead of glibc for C library
2. **Static linking** of all dependencies
3. **ELF patching** to use custom interpreter
4. **Relative paths** with $ORIGIN for libraries
5. **Wrapper scripts** for environment setup

### What is the musl interpreter in /tmp?

The file `/tmp/StAnDaLoNeMuSlInTeRpReTeR-musl-x86_64.so` is the musl C library that serves as the dynamic linker. It's copied there because:
- `/tmp` is always writable
- Allows execution without root
- Cleaned automatically on reboot
- Unique name prevents conflicts

### Why are there wrapper scripts?

The wrapper scripts (`python-wrapper`, `pip-wrapper`) handle:
- Setting up PYTHONPATH and PYTHONHOME
- Copying musl interpreter to /tmp
- Finding the real Python binary
- Managing environment variables
- Ensuring proper library paths

### What's the difference between python and python-real?

- `python` → Wrapper script (entry point)
- `python3.12-real` → Actual Python binary

The wrapper prepares the environment before executing the real binary.

### Can I move the installation after extraction?

Yes! Standalone Python is completely relocatable:
```bash
# Move anywhere
mv opt /any/location/
/any/location/python/bin/python --version  # Works!
```

## Comparison with Alternatives

### How does this compare to python-build-standalone?

| Feature | Standalone Python | python-build-standalone |
|---------|------------------|------------------------|
| GLIBC dependency | ❌ None | ✅ Required |
| Legacy system support | ✅ Kernel 2.6.32+ | ❌ Modern glibc only |
| Size | ~70MB | ~40MB |
| Portability | ✅ Any Linux | ⚠️ Matching glibc |
| Runtime pip | ✅ Full support | ✅ Full support |

### How does this compare to PyInstaller?

| Feature | Standalone Python | PyInstaller |
|---------|------------------|-------------|
| Purpose | Portable interpreter | Application bundling |
| Run scripts | ✅ Any Python script | ❌ Only bundled app |
| Install packages | ✅ pip works | ❌ Pre-bundled only |
| Development | ✅ Full REPL | ❌ No REPL |
| Size | ~70MB base | Variable per app |

### How does this compare to Docker?

| Feature | Standalone Python | Docker Python |
|---------|------------------|---------------|
| Requirements | None | Docker daemon |
| Overhead | Minimal | Container overhead |
| Integration | Direct | Container boundary |
| Root needed | ❌ No | ⚠️ For daemon |
| Isolation | Process-level | Container-level |

### How does this compare to Conda?

| Feature | Standalone Python | Conda |
|---------|------------------|-------|
| Dependencies | All bundled | Downloads required |
| Internet needed | ❌ No | ✅ Yes |
| Package manager | pip | conda + pip |
| Size | ~70MB | ~500MB+ |
| Environments | venv | conda env |

### When should I use Standalone Python vs alternatives?

**Use Standalone Python when**:
- System has incompatible/old glibc
- No root access available
- Need portable Python across systems
- Working with legacy/embedded systems
- Want minimal dependencies

**Use alternatives when**:
- System has modern glibc (python-build-standalone)
- Building standalone applications (PyInstaller)
- Need full isolation (Docker)
- Want scientific packages (Conda)

## Build & Development

### How long does building take?

Build times on typical hardware:
- Single version/arch: 2-3 hours
- All versions/archs: 12-18 hours
- With caching: 30-60 minutes

Factors affecting build time:
- CPU cores (parallel builds)
- Network speed (downloading sources)
- Docker cache (subsequent builds)

### Can I customize the Python build?

Yes, modify `deplib/build_python.sh`:
```bash
# Add configure options
./configure \
    --enable-your-option \
    --with-your-feature \
    ...
```

### How do I add a new Python version?

1. Copy existing version directory
2. Update PYTHON_VERSION in Dockerfile
3. Test the build
4. Update CI/CD configuration

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

### Can I reduce the size?

Yes, several approaches:
```bash
# Remove test suite
rm -rf /opt/python/lib/python3.12/test

# Remove unused modules
rm -rf /opt/python/lib/python3.12/tkinter

# Strip debugging symbols
strip --strip-all /opt/python/bin/*

# Use compression
upx /opt/python/bin/python3.12-real
```

### How do I build for ARM/other architectures?

Currently not supported, but possible:
1. Modify musl build for target arch
2. Update Docker base image
3. Adjust compilation flags
4. Cross-compile or use QEMU

## Troubleshooting

### Why does Python fail to start?

Common causes and solutions:

1. **Wrong architecture**:
```bash
uname -m  # Check your system
file opt/python/bin/python3.12-real  # Check binary
```

2. **Missing /tmp access**:
```bash
ls -ld /tmp  # Should be drwxrwxrwt
df -h /tmp   # Check space
```

3. **Corrupted extraction**:
```bash
tar -tzf release-*.tar.gz > /dev/null  # Test archive
```

### Why can't pip install packages?

1. **Network issues**:
```bash
# Test connectivity
curl https://pypi.org

# Use proxy if needed
export HTTPS_PROXY=http://proxy:8080
```

2. **SSL certificates**:
```bash
# Update certificates
./opt/python/bin/pip install --upgrade certifi
```

3. **Permissions**:
```bash
# Check write permissions
ls -ld opt/python/lib/python3.12/site-packages/
```

### Why is it slower than system Python?

Possible reasons:
- First run copies musl to /tmp (one-time)
- Wrapper script overhead (~10ms)
- No system optimization flags
- Debug build (if custom compiled)

Solutions:
- Use -O flag for optimization
- Pre-compile with python -m compileall
- Ensure using release build

### Why do I get "command not found"?

The Python binary isn't in PATH:
```bash
# Use full path
/path/to/opt/python/bin/python

# Or add to PATH
export PATH="/path/to/opt/python/bin:$PATH"

# Or create alias
alias spy='/path/to/opt/python/bin/python'
```

## Performance & Security

### Is Standalone Python slower than regular Python?

Performance comparison:
- **Startup**: ~50ms slower (wrapper overhead)
- **Runtime**: Identical performance
- **Memory**: ~5MB additional (bundled libraries)

The performance difference is negligible for most applications.

### Is Standalone Python secure?

Security features:
- Regular security updates
- All standard Python security features
- No system library vulnerabilities
- Read-only binary permissions
- Can run without root

Best practices:
- Keep updated to latest release
- Verify downloads with checksums
- Use virtual environments
- Follow standard Python security guidelines

### Can I use it in production?

Yes, with considerations:
- ✅ Fully functional Python
- ✅ Compatible with all pure Python packages
- ✅ C extensions work if compiled correctly
- ⚠️ Larger size than system Python
- ⚠️ Manual updates required

### Does it work in containers?

Excellent for containers:
```dockerfile
FROM scratch  # or alpine:latest
COPY release-3.12-x86_64.tar.gz /tmp/
RUN tar -xzf /tmp/release-3.12-x86_64.tar.gz -C /
ENV PATH="/opt/python/bin:$PATH"
CMD ["python"]
```

Benefits:
- No base image Python needed
- Consistent across all Linux containers
- Smaller than most Python base images
- Works with minimal base images

### Can I use GPU libraries?

Yes, but with setup:
1. GPU libraries need to be accessible
2. CUDA/ROCm must be installed on host
3. May need to set library paths
4. Test thoroughly

Example:
```bash
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
./opt/python/bin/python gpu_script.py
```

## More Questions?

### Where can I get help?

1. **Documentation**: Check docs/ directory
2. **GitHub Issues**: Report bugs
3. **Discussions**: Ask questions
4. **Stack Overflow**: Tag `standalone-python`

### How can I contribute?

See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development setup
- Contribution guidelines
- Code style
- Testing requirements

### Is commercial use allowed?

Yes! Standalone Python is MIT licensed:
- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Private use

Dependencies follow their respective licenses (mostly MIT/BSD/Apache).

### How often are releases made?

Release schedule:
- Security updates: As needed
- Python updates: Following official releases
- Feature releases: Quarterly
- Dependency updates: Monthly review

### Can I request features?

Yes! Open a GitHub issue with:
- Use case description
- Expected behavior
- Why it's valuable
- Possible implementation

---

*Didn't find your question? Open an issue or start a discussion on GitHub!*