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

if [ ! -f $SOURCE_DIR/check/$PACKAGE_STRING ]; then
  header $PACKAGE $PACKAGE_VERSION

  # Cleanup possible leftovers
  rm -Rf build

  LLVM=llvm-$LLVM_VERSION

  # Crappy CentOS 5.6 doesnt like us to build Clang, so skip it
  RELEASE_NAME=`lsb_release -r -i`
  if [[ ! "$RELEASE_NAME" =~ CentOS.*5\.[[:digit:]] ]]; then
    cd tools
    # CLANG
    tar zxf ../../cfe-$LLVM_VERSION.src.tar.gz
    mv cfe-$LLVM_VERSION.src clang
    # COMPILER RT
    cd ../projects
    tar zxf ../../compiler-rt-$LLVM_VERSION.src.tar.gz
    mv compiler-rt-$LLVM_VERSION.src compiler-rt-3.5.0.src.tar.gz
    cd ../../
  else
    cd ..
  fi

  mkdir -p build
  cd build

  # Some ancient systems have another python installed
  PY_VERSION=`python -V 2>&1`
  EXTRA_CONFIG_ARG=
  if [[ "$PY_VERSION" =~ "Python 2\.4\.." ]]; then
      # Typically on the systems having Python 2.4, they have a separate install
      # of Python 2.6 wiht a python26 executable. However, this is not generally
      # true for all platforms.
      EXTRA_CONFIG_ARG=--with-python=`which python26`
  fi

  ../$LLVM.src/configure $EXTRA_CONFIG_ARG --prefix=$LOCAL_INSTALL --with-pic --with-gcc-toolchain=$BUILD_DIR/gcc-$GCC_VERSION --with-extra-ld-options="$LDFLAGS" > $BUILD_LOG 2>&1

  make -j${IMPALA_BUILD_THREADS:-4} REQUIRES_RTTI=1 install >> $BUILD_LOG 2>&1

  footer $PACKAGE $PACKAGE_VERSION
fi
