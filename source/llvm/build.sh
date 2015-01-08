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

if [ ! -f $SOURCE_DIR/check/llvm-$LLVM_VERSION ]; then
  LLVM=llvm-$LLVM_VERSION
  cd $SOURCE_DIR/source/llvm

  # Cleanup possible leftovers
  rm -Rf build
  rm -Rf $LLVM.src

  # LLVM
  tar zxf $LLVM.src.tar.gz
  cd $LLVM.src/tools

  # CLANG
  tar zxf ../../cfe-$LLVM_VERSION.src.tar.gz
  mv cfe-$LLVM_VERSION.src clang

  # COMPILER RT
  cd ../projects
  tar zxf ../../compiler-rt-$LLVM_VERSION.src.tar.gz
  mv compiler-rt-$LLVM_VERSION.src compiler-rt

  cd ../../
  mkdir build
  cd build

  LOCAL_INSTALL=$BUILD_DIR/$LLVM
  BUILD_LOG=$SOURCE_DIR/check/llvm-$LLVM_VERSION.log

  ../$LLVM.src/configure --prefix=$LOCAL_INSTALL --with-pic --with-gcc-toolchain=$BUILD_DIR/gcc-$GCC_VERSION --with-extra-ld-options="$LDFLAGS" > $BUILD_LOG 2>&1

  make -j${IMPALA_BUILD_THREADS:-4} REQUIRES_RTTI=1 install >> $BUILD_LOG 2>&1

  touch $SOURCE_DIR/check/llvm-$LLVM_VERSION
fi
