#!/bin/bash
# Copyright 2012 Cloudera Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -eu

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR

if needs_build_package ; then

  if [[ $PACKAGE_VERSION = "trunk" ]]; then
    . $SOURCE_DIR/source/llvm/build-trunk.sh
    cd $SOURCE_DIR/source/llvm
    build_trunk
  elif [[ "$PACKAGE_VERSION" =~ "3.7" ]]; then
    . $SOURCE_DIR/source/llvm/build-3.7.x.sh
    cd $SOURCE_DIR/source/llvm
    build_llvm
  else
    header $PACKAGE $PACKAGE_VERSION
    LLVM=llvm-$LLVM_VERSION

    # Cleanup possible leftovers
    rm -Rf build-$LLVM
    rm -Rf $LLVM.src

    # Crappy CentOS 5.6 doesnt like us to build Clang, so skip it
    cd tools
    # CLANG
    tar zxf ../../cfe-$PACKAGE_VERSION.src.tar.gz
    mv cfe-$PACKAGE_VERSION.src clang

    # CLANG Extras
    cd clang/tools
    tar zxf ../../../../clang-tools-extra-$PACKAGE_VERSION.src.tar.gz
    mv clang-tools-extra-$PACKAGE_VERSION.src extra
    cd ../../

    # COMPILER RT
    cd ../projects
    tar zxf ../../compiler-rt-$PACKAGE_VERSION.src.tar.gz
    mv compiler-rt-$PACKAGE_VERSION.src compiler-rt
    cd ../../

    mkdir -p build-$LLVM
    cd build-$LLVM

    # Some ancient systems have another python installed
    PY_VERSION=`python -V 2>&1`
    EXTRA_CONFIG_ARG=
    if [[ "$PY_VERSION" =~ "Python 2\.4\.." ]]; then
      # Typically on the systems having Python 2.4, they have a separate install
      # of Python 2.6 wiht a python26 executable. However, this is not generally
      # true for all platforms.
      EXTRA_CONFIG_ARG=--with-python=`which python26`
    fi

    if [[ ! "$OSTYPE" == "darwin"* ]]; then
      EXTRA_CONFIG_ARG="$EXTRA_CONFIG_ARG --with-gcc-toolchain=$BUILD_DIR/gcc-$GCC_VERSION"
    fi

    echo "$EXTRA_CONFIG_ARG"
    wrap ../llvm-$PACKAGE_VERSION.src$PATCH_VERSION/configure --enable-targets=x86_64,cpp --enable-optimized --enable-terminfo=no --prefix=$LOCAL_INSTALL --with-pic $EXTRA_CONFIG_ARG --with-extra-ld-options="$LDFLAGS"

    wrap make -j${BUILD_THREADS:-4} REQUIRES_RTTI=1 install

    # Do not forget to install clang as well
    cd tools/clang
    wrap make -j${BUILD_THREADS:-4} REQUIRES_RTTI=1 install

    footer $PACKAGE $PACKAGE_VERSION
  fi
fi
