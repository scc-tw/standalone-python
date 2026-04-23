#!/bin/sh
#
# Install pip into the Python 2.7 tree. Separate from install_pip.sh
# because Python 2 needs the pypa-maintained 2.7 bootstrap of get-pip.py
# (the generic bootstrap URL only accepts Python 3), and the last pip
# that supports Python 2 is 20.3.4 (setuptools 44.1.1).

export PYTHON_PIP_VERSION=${PYTHON_PIP_VERSION:-20.3.4}
export PYTHON_SETUPTOOLS_VERSION=${PYTHON_SETUPTOOLS_VERSION:-44.1.1}
export PYTHON_GET_PIP_URL=${PYTHON_GET_PIP_URL:-https://bootstrap.pypa.io/pip/2.7/get-pip.py}
export PYTHON_PATH=/opt/python/bin/python2

wget -O get-pip.py "$PYTHON_GET_PIP_URL"
export PYTHONDONTWRITEBYTECODE=1

export LD_LIBRARY_PATH="/opt/python/lib:$LD_LIBRARY_PATH"
$PYTHON_PATH get-pip.py --disable-pip-version-check --no-cache-dir --no-compile \
    "pip==$PYTHON_PIP_VERSION" "setuptools==$PYTHON_SETUPTOOLS_VERSION"
rm -f get-pip.py

export PIP_PATH=/opt/python/bin/pip2
$PIP_PATH --version # buildkit
