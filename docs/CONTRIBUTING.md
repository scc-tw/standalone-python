# Contributing Guide

Thank you for your interest in contributing to Standalone Python! This guide will help you get started with development, testing, and submitting contributions.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Code Style](#code-style)
- [Documentation](#documentation)
- [Community Guidelines](#community-guidelines)

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- Git installed and configured
- Docker (version 20.10+)
- Basic knowledge of Python and shell scripting
- Understanding of Docker and containerization
- Familiarity with Linux systems

### Fork and Clone

1. **Fork the repository** on GitHub
2. **Clone your fork**:
```bash
git clone https://github.com/YOUR-USERNAME/standalone-python.git
cd standalone-python
```

3. **Add upstream remote**:
```bash
git remote add upstream https://github.com/original-repo/standalone-python.git
git fetch upstream
```

### Understanding the Project

Before making changes:

1. Read the [README.md](../README.md)
2. Review the [ARCHITECTURE.md](ARCHITECTURE.md)
3. Check existing [Issues](https://github.com/your-repo/standalone-python/issues)
4. Look at recent [Pull Requests](https://github.com/your-repo/standalone-python/pulls)

## Development Setup

### Setting Up Your Environment

1. **Install development tools**:
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y docker.io git make wget curl

# Fedora/RHEL
sudo dnf install -y docker git make wget curl
```

2. **Configure Docker**:
```bash
# Add yourself to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify Docker works
docker run hello-world
```

3. **Set up development directory**:
```bash
mkdir -p ~/dev/standalone-python
cd ~/dev/standalone-python
git clone <your-fork-url> .
```

### Building Locally

Test your development environment:

```bash
# Build a single version for testing
docker build -t dev-python:3.12-x86_64 ./3.12/x86_64/

# Quick build (skip optimization for development)
docker build --build-arg CFLAGS="-O0" -t dev-python:quick ./3.12/x86_64/
```

## Project Structure

Understanding the project layout:

```
standalone-python/
├── .github/
│   └── workflows/      # GitHub Actions CI/CD
│       └── build.yml
├── .gitlab-ci.yml      # GitLab CI/CD
├── 3.10/              # Python 3.10 builds
│   ├── x86/
│   └── x86_64/
├── 3.11/              # Python 3.11 builds
│   ├── x86/
│   └── x86_64/
├── 3.12/              # Python 3.12 builds
│   ├── x86/
│   └── x86_64/
│       ├── Dockerfile          # Main build file
│       ├── deplib/            # Dependency build scripts
│       │   ├── build_*.sh    # Individual component builds
│       │   └── patch/        # Patches for dependencies
│       ├── interpreter-patcher.sh  # ELF modification
│       ├── packing-initializer    # Package preparation
│       ├── pip-wrapper            # Pip wrapper script
│       └── python-wrapper         # Python wrapper script
├── assets/            # Images and resources
├── ci/               # CI/CD utilities
├── docs/             # Documentation
├── LICENSE           # MIT License
└── README.md         # Project overview
```

### Key Files to Understand

| File | Purpose | When to Modify |
|------|---------|----------------|
| `Dockerfile` | Build configuration | Adding stages or dependencies |
| `deplib/build_*.sh` | Dependency compilation | Updating versions or flags |
| `*-wrapper` | Runtime wrappers | Changing execution behavior |
| `interpreter-patcher.sh` | ELF patching | Modifying binary structure |
| `.github/workflows/build.yml` | GitHub CI/CD | Updating build process |

## Making Changes

### Types of Contributions

1. **Bug Fixes**: Fixing issues in build scripts or wrappers
2. **Feature Additions**: New Python versions or architectures
3. **Dependency Updates**: Updating component versions
4. **Documentation**: Improving or adding documentation
5. **Performance**: Optimization improvements
6. **Testing**: Adding test coverage

### Development Workflow

1. **Create a feature branch**:
```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-description
```

2. **Make your changes**:
```bash
# Edit files
vim 3.12/x86_64/deplib/build_python.sh

# Test your changes
docker build -t test ./3.12/x86_64/
```

3. **Commit your changes**:
```bash
git add .
git commit -m "feat: add support for Python 3.13"
```

### Adding a New Python Version

Example: Adding Python 3.13 support

1. **Create directory structure**:
```bash
cp -r 3.12 3.13
```

2. **Update version in build files**:
```bash
# In 3.13/x86_64/Dockerfile
ENV PYTHON_VERSION=3.13.0

# In 3.13/x86_64/deplib/build_python.sh
wget "https://www.python.org/ftp/python/3.13.0/Python-3.13.0.tar.xz"
```

3. **Update CI/CD**:
```yaml
# In .github/workflows/build.yml
version: ["3.13", "3.12", "3.11", "3.10"]
```

4. **Test thoroughly**:
```bash
docker build -t python:3.13-x86_64 ./3.13/x86_64/
docker run --rm python:3.13-x86_64 /opt/python/bin/python --version
```

### Updating Dependencies

Example: Updating OpenSSL

1. **Find the build script**:
```bash
vim 3.12/x86_64/deplib/build_openssl.sh
```

2. **Update version**:
```bash
# Change version
OPENSSL_VERSION="1.1.1x"  # New version
```

3. **Test the build**:
```bash
# Build only the OpenSSL stage
docker build --target openssl_builder -t test-openssl ./3.12/x86_64/
```

4. **Verify functionality**:
```bash
docker run --rm test-openssl openssl version
```

## Testing

### Local Testing

1. **Build testing**:
```bash
#!/bin/bash
# test-build.sh

VERSIONS=("3.10" "3.11" "3.12")
ARCHES=("x86_64" "x86")

for ver in "${VERSIONS[@]}"; do
    for arch in "${ARCHES[@]}"; do
        echo "Testing $ver-$arch..."
        docker build -t test:$ver-$arch ./$ver/$arch/ || exit 1
        docker run --rm test:$ver-$arch \
            /opt/python/bin/python -c "import sys; print(sys.version)"
    done
done
```

2. **Functional testing**:
```python
# test_standalone.py
import sys
import ssl
import sqlite3
import json
import zlib

print(f"Python: {sys.version}")
print(f"SSL: {ssl.OPENSSL_VERSION}")
print(f"SQLite: {sqlite3.sqlite_version}")
print("All modules loaded successfully!")
```

3. **Extraction testing**:
```bash
# Extract and test
docker run --rm test:3.12-x86_64 tar czf - -C /opt python | tar xzf -
./python/bin/python --version
./python/bin/pip --version
```

### Automated Testing

Add tests to CI/CD:

```yaml
# .github/workflows/test.yml
name: Test Build
on: [pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Test Python build
        run: |
          docker build -t test ./3.12/x86_64/
          docker run --rm test /opt/python/bin/python -m pytest
```

### Performance Testing

```bash
# Benchmark script
time docker build -t bench ./3.12/x86_64/

# Test startup time
time docker run --rm test:3.12-x86_64 \
    /opt/python/bin/python -c "print('hello')"

# Memory usage
docker stats --no-stream test-container
```

## Submitting Changes

### Pre-Submission Checklist

- [ ] Code follows project style guidelines
- [ ] All tests pass
- [ ] Documentation updated if needed
- [ ] Commit messages follow convention
- [ ] Branch is up to date with upstream/main
- [ ] No unnecessary files committed

### Commit Message Convention

Follow conventional commits format:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Test additions or fixes
- `build`: Build system changes
- `ci`: CI/CD changes
- `chore`: Maintenance tasks

Examples:
```bash
feat(python): add support for Python 3.13
fix(build): resolve OpenSSL compilation error on x86
docs: update installation instructions
perf(docker): optimize build caching
```

### Creating a Pull Request

1. **Push your branch**:
```bash
git push origin feature/your-feature-name
```

2. **Create PR on GitHub**:
- Go to your fork on GitHub
- Click "New Pull Request"
- Select your branch
- Fill in the template

3. **PR Template**:
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement

## Testing
- [ ] Built successfully
- [ ] Tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes
```

## Code Style

### Shell Scripts

```bash
#!/bin/sh
# Use sh, not bash for portability

set -eux  # Exit on error, undefined vars, print commands

# Functions use snake_case
function_name() {
    local var="$1"
    echo "Processing: ${var}"
}

# Variables use UPPER_CASE for exports
export BUILD_DIR="/tmp/build"

# Use quotes around variables
if [ -f "$BUILD_DIR/file" ]; then
    rm -f "$BUILD_DIR/file"
fi
```

### Dockerfiles

```dockerfile
# Group related commands
RUN set -eux && \
    apt-get update && \
    apt-get install -y package1 package2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Use specific versions
FROM alpine:3.18.3

# Label your stages
FROM base AS builder

# Minimize layers
COPY ["file1", "file2", "destination/"]
```

### Python Code

```python
#!/usr/bin/env python3
"""Module docstring."""

import os
import sys

def function_name(parameter: str) -> bool:
    """Function docstring.

    Args:
        parameter: Description

    Returns:
        bool: Description
    """
    return True

if __name__ == "__main__":
    sys.exit(0 if function_name("test") else 1)
```

## Documentation

### Documentation Standards

- Use Markdown for all documentation
- Include code examples
- Keep language clear and concise
- Update docs with code changes
- Add diagrams where helpful

### Adding Documentation

1. **Identify where to document**:
   - User-facing changes → README.md
   - Technical details → TECHNICAL.md
   - Usage examples → USAGE.md
   - Architecture changes → ARCHITECTURE.md

2. **Write clear documentation**:
```markdown
## Feature Name

Brief description of the feature.

### Usage

\```bash
# Example command
./opt/python/bin/python script.py
\```

### Configuration

| Option | Description | Default |
|--------|-------------|---------|
| --flag | What it does | value |
```

3. **Test documentation**:
   - Verify code examples work
   - Check links are valid
   - Ensure formatting is correct

## Community Guidelines

### Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Give constructive feedback
- Focus on what's best for the community
- Show empathy towards others

### Getting Help

- **Questions**: Open a [Discussion](https://github.com/your-repo/standalone-python/discussions)
- **Bugs**: Open an [Issue](https://github.com/your-repo/standalone-python/issues)
- **Ideas**: Start a Discussion first
- **Security**: Email security@example.com

### Review Process

1. **Automated checks** run on all PRs
2. **Maintainer review** within 1-2 weeks
3. **Feedback addressed** by contributor
4. **Approval and merge** by maintainer

### Becoming a Maintainer

Active contributors may be invited to become maintainers based on:

- Quality of contributions
- Consistency of participation
- Understanding of the project
- Helpful to other contributors

## Recognition

Contributors are recognized in:
- The CONTRIBUTORS file
- Release notes
- Project README

Thank you for contributing to Standalone Python! Your efforts help make Python accessible everywhere.

---

*For questions about contributing, please open a discussion or reach out to the maintainers.*