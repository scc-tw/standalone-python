#!/bin/sh

set -e
export TCL_VERSION=8.6.13
# http://prdownloads.sourceforge.net/tcl/tcl8.6.13-src.tar.gz

wget http://prdownloads.sourceforge.net/tcl/tcl${TCL_VERSION}-src.tar.gz
tar -xzf tcl${TCL_VERSION}-src.tar.gz && cd tcl${TCL_VERSION}/unix

./configure --prefix=/opt/shared_libraries
make -j $(nproc) && make install
