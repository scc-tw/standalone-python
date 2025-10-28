# Usage Guide

Learn how to use Standalone Python for running scripts, installing packages, and integrating with your projects.

## Table of Contents

- [Running Python Scripts](#running-python-scripts)
- [Interactive Python Shell](#interactive-python-shell)
- [Using Pip](#using-pip)
- [Environment Variables](#environment-variables)
- [Integration](#integration)
- [Best Practices](#best-practices)
- [Advanced Usage](#advanced-usage)

## Running Python Scripts

### Basic Script Execution

Run Python scripts just like with regular Python:

```bash
# Direct execution
./opt/python/bin/python script.py

# With arguments
./opt/python/bin/python script.py arg1 arg2

# From different directory
/path/to/opt/python/bin/python /path/to/script.py
```

### Script with Shebang

Make your scripts executable with Standalone Python:

```python
#!/path/to/opt/python/bin/python
# -*- coding: utf-8 -*-

print("Hello from Standalone Python!")
```

Then make it executable:
```bash
chmod +x myscript.py
./myscript.py
```

### Running Modules

Execute Python modules directly:

```bash
# Run module as script
./opt/python/bin/python -m http.server 8000

# Run pip as module
./opt/python/bin/python -m pip install requests

# Run tests
./opt/python/bin/python -m pytest

# Profile code
./opt/python/bin/python -m cProfile script.py
```

## Interactive Python Shell

### Starting the REPL

Launch the interactive Python interpreter:

```bash
# Start interactive shell
./opt/python/bin/python

# With startup script
./opt/python/bin/python -i startup.py

# Quiet mode (no banner)
./opt/python/bin/python -q
```

### REPL Features

The Standalone Python REPL includes all standard features:

```python
>>> import sys
>>> sys.version
'3.12.3 (main, ..., ...) [GCC 13.2.0]'

>>> # Tab completion works
>>> import os
>>> os.<TAB>  # Shows available methods

>>> # History with arrow keys
>>> # Previous commands accessible with ↑/↓
```

### IPython Integration

Install and use IPython for enhanced interactive experience:

```bash
# Install IPython
./opt/python/bin/pip install ipython

# Start IPython
./opt/python/bin/ipython
```

## Using Pip

### Installing Packages

Install Python packages from PyPI:

```bash
# Install a single package
./opt/python/bin/pip install requests

# Install specific version
./opt/python/bin/pip install django==4.2.0

# Install from requirements file
./opt/python/bin/pip install -r requirements.txt

# Install with extras
./opt/python/bin/pip install 'celery[redis]'
```

### Managing Packages

```bash
# List installed packages
./opt/python/bin/pip list

# Show package details
./opt/python/bin/pip show numpy

# Upgrade packages
./opt/python/bin/pip install --upgrade requests

# Uninstall packages
./opt/python/bin/pip uninstall requests
```

### Package Installation Location

Packages are installed in the self-contained site-packages:

```bash
# View installation directory
./opt/python/bin/python -c "import site; print(site.getsitepackages())"
# Output: ['/path/to/opt/python/lib/python3.12/site-packages']

# Packages are isolated from system Python
ls opt/python/lib/python3.12/site-packages/
```

### Virtual Environments

Create virtual environments for project isolation:

```bash
# Create virtual environment
./opt/python/bin/python -m venv myenv

# Activate virtual environment
source myenv/bin/activate

# Install packages in venv
pip install flask

# Deactivate
deactivate
```

### Using pip with Proxy

Configure pip to work behind a proxy:

```bash
# Set proxy for pip
./opt/python/bin/pip install --proxy http://proxy.example.com:8080 requests

# Or set environment variable
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080
./opt/python/bin/pip install requests
```

## Environment Variables

### Python-Specific Variables

Standalone Python respects standard Python environment variables:

```bash
# Set Python path
export PYTHONPATH=/my/modules:$PYTHONPATH
./opt/python/bin/python script.py

# Disable bytecode generation
export PYTHONDONTWRITEBYTECODE=1
./opt/python/bin/python script.py

# Enable optimization
export PYTHONOPTIMIZE=1
./opt/python/bin/python script.py

# Set encoding
export PYTHONIOENCODING=utf-8
./opt/python/bin/python script.py
```

### Standalone Python Variables

The wrapper scripts handle these automatically, but you can override:

```bash
# Python home (automatically set by wrapper)
export PYTHONHOME=/path/to/opt/python

# Library path (automatically set by wrapper)
export LD_LIBRARY_PATH=/path/to/opt/python/shared_libraries/lib:$LD_LIBRARY_PATH
```

### Debugging Environment

Enable debugging output:

```bash
# Python verbose mode
./opt/python/bin/python -v script.py

# Trace imports
./opt/python/bin/python -vv script.py

# Debug pip
./opt/python/bin/pip install --verbose --debug requests
```

## Integration

### Shell Scripts

Integrate Standalone Python in shell scripts:

```bash
#!/bin/bash
# deploy.sh

PYTHON=/opt/python/bin/python
PIP=/opt/python/bin/pip

# Check Python version
$PYTHON --version

# Install dependencies
$PIP install -r requirements.txt

# Run application
$PYTHON app.py
```

### Makefiles

Use in Makefiles:

```makefile
PYTHON := /opt/python/bin/python
PIP := /opt/python/bin/pip

install:
    $(PIP) install -r requirements.txt

test:
    $(PYTHON) -m pytest tests/

run:
    $(PYTHON) app.py

clean:
    find . -type d -name __pycache__ -exec rm -rf {} +
```

### Docker Integration

Use Standalone Python in Docker containers:

```dockerfile
FROM debian:bullseye-slim

# Copy Standalone Python
COPY release-3.12-x86_64.tar.gz /tmp/
RUN tar -xzf /tmp/release-3.12-x86_64.tar.gz -C / && \
    rm /tmp/release-3.12-x86_64.tar.gz

# Set PATH
ENV PATH="/opt/python/bin:${PATH}"

# Install dependencies
COPY requirements.txt .
RUN python -m pip install -r requirements.txt

# Copy application
COPY . /app
WORKDIR /app

CMD ["python", "app.py"]
```

### CI/CD Pipelines

GitHub Actions example:

```yaml
name: Test with Standalone Python

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Download Standalone Python
        run: |
          wget https://github.com/your-repo/standalone-python/releases/latest/download/release-3.12-x86_64.tar.gz
          tar -xzf release-3.12-x86_64.tar.gz

      - name: Install dependencies
        run: |
          ./opt/python/bin/pip install -r requirements.txt

      - name: Run tests
        run: |
          ./opt/python/bin/python -m pytest
```

### Cron Jobs

Schedule Python scripts with cron:

```bash
# Edit crontab
crontab -e

# Add job (runs daily at 2 AM)
0 2 * * * /path/to/opt/python/bin/python /path/to/script.py >> /var/log/myscript.log 2>&1
```

## Best Practices

### 1. Path Management

Create convenient aliases:

```bash
# Add to ~/.bashrc
alias spy='/path/to/opt/python/bin/python'
alias spip='/path/to/opt/python/bin/pip'

# Use aliases
spy script.py
spip install requests
```

### 2. Wrapper Scripts

Create project-specific wrappers:

```bash
#!/bin/bash
# run.sh
exec /opt/python/bin/python "$@"
```

### 3. Dependency Management

Always use requirements files:

```bash
# Generate requirements
./opt/python/bin/pip freeze > requirements.txt

# Install from requirements
./opt/python/bin/pip install -r requirements.txt
```

### 4. Version Checking

Verify compatibility in scripts:

```python
import sys

# Check Python version
if sys.version_info < (3, 10):
    print("Error: Python 3.10+ required")
    sys.exit(1)

# Check Standalone Python
if "standalone" not in sys.executable.lower():
    print("Warning: Not running with Standalone Python")
```

### 5. Resource Management

Monitor temporary file usage:

```bash
# Check musl interpreter in /tmp
ls -la /tmp/StAnDaLoNeMuSlInTeRpReTeR-*.so

# Clean if needed (automatically recreated)
rm -f /tmp/StAnDaLoNeMuSlInTeRpReTeR-*.so
```

## Advanced Usage

### Custom Module Path

Add custom module directories:

```python
import sys
sys.path.insert(0, '/my/custom/modules')

# Now you can import from custom location
import mymodule
```

### Embedding in Applications

Use Standalone Python as an embedded interpreter:

```c
// C application
#include <stdlib.h>

int main() {
    system("/opt/python/bin/python -c 'print(\"Embedded Python!\")'");
    return 0;
}
```

### Performance Profiling

Profile your applications:

```bash
# Basic profiling
./opt/python/bin/python -m cProfile -o profile.stats script.py

# Analyze profile
./opt/python/bin/python -c "
import pstats
stats = pstats.Stats('profile.stats')
stats.sort_stats('cumulative')
stats.print_stats(10)
"
```

### Building C Extensions

Compile C extensions with Standalone Python:

```bash
# Install build tools
./opt/python/bin/pip install setuptools wheel

# Build extension
./opt/python/bin/python setup.py build_ext --inplace

# Install extension
./opt/python/bin/pip install .
```

### Network Services

Run network services:

```bash
# Simple HTTP server
./opt/python/bin/python -m http.server 8000 --bind 0.0.0.0

# WSGI application
./opt/python/bin/pip install gunicorn
./opt/python/bin/gunicorn app:application
```

### Debugging

Debug Python applications:

```bash
# Start debugger
./opt/python/bin/python -m pdb script.py

# Post-mortem debugging
./opt/python/bin/python -m pdb -c continue script.py

# Remote debugging with debugpy
./opt/python/bin/pip install debugpy
./opt/python/bin/python -m debugpy --listen 5678 script.py
```

## Common Patterns

### Script Template

Standard template for Standalone Python scripts:

```python
#!/usr/bin/env /opt/python/bin/python
"""
Script description here.
"""

import sys
import os
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def main():
    """Main function."""
    logger.info("Starting script...")

    # Your code here

    logger.info("Script completed successfully")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

### Error Handling

Robust error handling pattern:

```python
import sys
import traceback

try:
    # Your code here
    import some_module
    result = some_module.process()

except ImportError as e:
    print(f"Error: Missing dependency - {e}", file=sys.stderr)
    print("Install with: /opt/python/bin/pip install <package>", file=sys.stderr)
    sys.exit(1)

except Exception as e:
    print(f"Unexpected error: {e}", file=sys.stderr)
    traceback.print_exc()
    sys.exit(1)
```

## Tips and Tricks

### Quick Commands

```bash
# One-liner calculations
./opt/python/bin/python -c "print(2**10)"

# JSON pretty-printing
echo '{"key": "value"}' | ./opt/python/bin/python -m json.tool

# Base64 encoding
echo "Hello" | ./opt/python/bin/python -m base64

# Simple HTTP server with custom port
./opt/python/bin/python -m http.server 9000

# Calendar
./opt/python/bin/python -c "import calendar; print(calendar.TextCalendar().formatyear(2024))"
```

### Performance Tips

1. **Use virtual environments** for project isolation
2. **Precompile bytecode** with `python -m compileall`
3. **Cache pip downloads** with `pip download` for offline installs
4. **Use wheels** instead of source distributions when possible

## Troubleshooting Usage Issues

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for solutions to common problems.

## Next Steps

- Understand the architecture: [ARCHITECTURE.md](ARCHITECTURE.md)
- Build from source: [BUILD.md](BUILD.md)
- Contribute to the project: [CONTRIBUTING.md](CONTRIBUTING.md)
- Read the FAQ: [FAQ.md](FAQ.md)

---

*For more examples and use cases, check our [GitHub repository](https://github.com/your-repo/standalone-python) or read the [FAQ](FAQ.md).*