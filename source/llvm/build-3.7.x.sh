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
set -o pipefail

function build_llvm() {
  header $PACKAGE $PACKAGE_VERSION
  LLVM=llvm-$LLVM_VERSION

  # Cleanup possible leftovers
  rm -Rf build-$LLVM
  rm -Rf $LLVM.src

  # Crappy CentOS 5.6 doesnt like us to build Clang, so skip it
  cd tools
  # CLANG
  tar xaf ../../cfe-$PACKAGE_VERSION.src.tar.xz
  mv cfe-$PACKAGE_VERSION.src clang

  # CLANG Extras
  cd clang/tools
  tar xaf ../../../../clang-tools-extra-$PACKAGE_VERSION.src.tar.xz
  mv clang-tools-extra-$PACKAGE_VERSION.src extra
  cd ../../

  # COMPILER RT
  cd ../projects
  tar xaf ../../compiler-rt-$PACKAGE_VERSION.src.tar.xz
  mv compiler-rt-$PACKAGE_VERSION.src compiler-rt
  cd ../../

  mkdir -p build-$LLVM
  cd build-$LLVM

  PYTHON_EXECUTABLE=$BUILD_DIR/python-$PYTHON_VERSION/bin/python
  if [[ "$OSTYPE" == "darwin"* ]]; then
    PYTHON_EXECUTABLE=/usr/bin/python
    CMAKE_EXEC=cmake
  else
    CMAKE_EXEC=$BUILD_DIR/cmake-$CMAKE_VERSION/bin/cmake
  fi

  # Invoke CMake with the correct configuration
  wrap $CMAKE_EXEC ../llvm-trunk \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
      -DLLVM_TARGETS_TO_BUILD=X86 \
      -DLLVM_ENABLE_RTTI=ON \
      -DLLVM_PARALLEL_COMPILE_JOBS=${BUILD_THREADS:-4} \
      -DLLVM_PARALLEL_LINK_JOBS=${BUILD_THREADS:-4} \
      -DPYTHON_EXECUTABLE=$PYTHON_EXECUTABLE

  wrap make -j${BUILD_THREADS:-4} install
  cd tools/clang
  wrap make -j${BUILD_THREADS:-4} install

  footer $PACKAGE $PACKAGE_VERSION
}
