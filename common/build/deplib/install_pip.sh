#!/bin/sh

set -e
. ./_fetch.sh

export PYTHON_PIP_VERSION=${PYTHON_PIP_VERSION:-23.2.1}
export PYTHON_SETUPTOOLS_VERSION=${PYTHON_SETUPTOOLS_VERSION:-65.5.1}
# Pin get-pip.py to pypa/get-pip's pip-26.0.1 release commit. The bundled
# bootstrap pip must itself be importable on the target interpreter; the
# previous 2024 pin (9af82b71...) predates pypa/pip#11685 which added
# `Distribution.locate_file`, and Python 3.15 promoted that method to
# `@abstractmethod` — so the old bootstrap pip fails to instantiate its
# own `WheelDistribution` subclass with
#   TypeError: Can't instantiate abstract class WheelDistribution
# mid-install of `pip==26.0.1`. Keeping the pinned commit aligned with
# PYTHON_PIP_VERSION below also eliminates bootstrap-vs-target skew.
export PYTHON_GET_PIP_URL=${PYTHON_GET_PIP_URL:-https://github.com/pypa/get-pip/raw/69fd2a8ffdc323a975d2f15eb4c2766cf28daaf7/public/get-pip.py}
export PYTHON_PATH=/opt/python/bin/python3

# get-pip.py has a stable official bootstrap; GitHub raw is our pin. If
# the raw URL ever flakes, bootstrap.pypa.io/get-pip.py is the official
# latest (but tracks head — would drift across CI runs, so only fallback).
fetch_mirrored get-pip.py \
    "$PYTHON_GET_PIP_URL" \
    "https://bootstrap.pypa.io/get-pip.py"

export PYTHONDONTWRITEBYTECODE=1

export LD_LIBRARY_PATH="/opt/python/lib:$LD_LIBRARY_PATH"
$PYTHON_PATH get-pip.py --disable-pip-version-check --no-cache-dir --no-compile "pip==$PYTHON_PIP_VERSION" "setuptools==$PYTHON_SETUPTOOLS_VERSION"
rm -f get-pip.py
export PIP_PATH=/opt/python/bin/pip3
$PIP_PATH --version # buildkit
