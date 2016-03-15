#!/bin/bash
# Copyright 2015 Cloudera Inc.
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

# Builds LLVM 3.7 and later from source tarballs.

set -eu
set -o pipefail

function build_llvm() {
  # Cleanup possible leftovers
  rm -Rf "$THIS_DIR/llvm-${PACKAGE_VERSION}.src"
  rm -Rf "$THIS_DIR/build-llvm-${PACKAGE_VERSION}"

  header $PACKAGE $PACKAGE_VERSION
  LLVM=llvm-$LLVM_VERSION

  rm -Rf $LLVM.src

  pushd tools
  # CLANG
  # tar on Centos 5.8 doesn't support -J flag, so specify xzcat manually.
  tar xf ../../cfe-$PACKAGE_VERSION.src.tar.xz --use-compress-program xzcat
  mv cfe-$PACKAGE_VERSION.src clang

  # CLANG Extras
  pushd clang/tools
  tar xf ../../../../clang-tools-extra-$PACKAGE_VERSION.src.tar.xz --use-compress-program xzcat
  mv clang-tools-extra-$PACKAGE_VERSION.src extra
  popd

  # COMPILER RT
  # Required for *Sanitizers and for using Clang's own C/C++ runtime.
  # Skip this on Centos 5.8 since it depends on perf_event.h.
  if [[ ! "$RELEASE_NAME" =~ CentOS.*5\.[[:digit:]] ]]; then
    pushd ../projects
    tar xf ../../compiler-rt-$PACKAGE_VERSION.src.tar.xz --use-compress-program xzcat
    mv compiler-rt-$PACKAGE_VERSION.src compiler-rt
    popd
  fi

  popd
  cd ..

  mkdir -p build-$LLVM
  cd build-$LLVM

  PYTHON_EXECUTABLE=$BUILD_DIR/python-$PYTHON_VERSION/bin/python
  if [[ "$OSTYPE" == "darwin"* ]]; then
    PYTHON_EXECUTABLE=/usr/bin/python
    export CXX=
    export CC=
    export CXXFLAGS=
    export LDFLAGS=
  fi

  # Invoke CMake with the correct configuration
  wrap cmake ../$LLVM.src \
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
