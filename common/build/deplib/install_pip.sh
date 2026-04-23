#!/bin/sh

export PYTHON_PIP_VERSION=23.2.1
export PYTHON_SETUPTOOLS_VERSION=65.5.1
export PYTHON_GET_PIP_URL=https://github.com/pypa/get-pip/raw/9af82b715db434abb94a0a6f3569f43e72157346/public/get-pip.py
export PYTHON_PATH=/opt/python/bin/python3

wget -O get-pip.py "$PYTHON_GET_PIP_URL"
export PYTHONDONTWRITEBYTECODE=1

export LD_LIBRARY_PATH="/opt/python/lib:$LD_LIBRARY_PATH"
$PYTHON_PATH get-pip.py --disable-pip-version-check --no-cache-dir --no-compile "pip==$PYTHON_PIP_VERSION" "setuptools==$PYTHON_SETUPTOOLS_VERSION"
rm -f get-pip.py
export PIP_PATH=/opt/python/bin/pip3
$PIP_PATH --version # buildkit
