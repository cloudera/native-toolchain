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

function build_trunk() {

  echo "#######################################################################"
  echo "# Building: LLVM-trunk"

  LPACKAGE_VERSION=llvm-trunk
  LPACKAGE=llvm
  BUILD_LOG=$SOURCE_DIR/check/llvm-trunk.log
  PATCH_VERSION=

  svn export http://llvm.org/svn/llvm-project/llvm/trunk llvm-trunk >> $BUILD_LOG 2>&1
  cd llvm-trunk/tools
  svn export http://llvm.org/svn/llvm-project/cfe/trunk clang >> $BUILD_LOG 2>&1
  cd ../..
  cd llvm-trunk/tools/clang/tools
  svn export http://llvm.org/svn/llvm-project/clang-tools-extra/trunk extra >> $BUILD_LOG 2>&1
  cd ../../../..
  cd llvm-trunk/projects
  svn export http://llvm.org/svn/llvm-project/compiler-rt/trunk compiler-rt >> $BUILD_LOG 2>&1

  # Back to the base directory
  cd ../..
  mkdir -p build-trunk
  cd build-trunk

  # Invoke CMake with the correct configuration
  wrap $BUILD_DIR/cmake-$CMAKE_VERSION/bin/cmake ../llvm-trunk \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=$BUILD_DIR/llvm-trunk \
      -DLLVM_TARGETS_TO_BUILD=X86 \
      -DLLVM_ENABLE_RTTI=ON \
      -DLLVM_PARALLEL_COMPILE_JOBS=${BUILD_THREADS:-4} \
      -DLLVM_PARALLEL_LINK_JOBS=${BUILD_THREADS:-4} \
      -DPYTHON_EXECUTABLE=$BUILD_DIR/python-$PYTHON_VERSION/bin/python

  wrap make -j${BUILD_THREADS:-4} install
  cd tools/clang
  wrap make -j${BUILD_THREADS:-4} install

  footer $PACKAGE $PACKAGE_VERSION
}
