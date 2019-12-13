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
  rm -Rf "$THIS_DIR/${PACKAGE_STRING}.src"
  rm -Rf "$THIS_DIR/build-${PACKAGE_STRING}"

  # The llvm source is composed of multiple archives, some of which are optional.
  # To allow unified patches across the entirety of the source, we extract all of the
  # desired archives in the appropriate places, and then use
  # setup_extracted_package_build, which can then apply patches across the whole
  # source tree.
  EXTRACTED_DIR="llvm-${SOURCE_VERSION}.src"
  TARGET_DIR="$PACKAGE_STRING.src"

  extract_archive "$THIS_DIR/llvm-${SOURCE_VERSION}.src.${ARCHIVE_EXT}"
  if [ "$EXTRACTED_DIR" != "$TARGET_DIR" ]; then
    mv "$EXTRACTED_DIR" "$TARGET_DIR"
  fi
  pushd "$TARGET_DIR"

  pushd tools
  # CLANG
  untar_xz ${THIS_DIR}/cfe-$SOURCE_VERSION.src.tar.xz
  mv cfe-$SOURCE_VERSION.src clang

  # CLANG Extras
  pushd clang/tools
  untar_xz ${THIS_DIR}/clang-tools-extra-$SOURCE_VERSION.src.tar.xz
  mv clang-tools-extra-$SOURCE_VERSION.src extra
  popd

  # COMPILER RT
  # Required for *Sanitizers and for using Clang's own C/C++ runtime.
  # Skip this on CentOS 5.8 since it depends on perf_event.h.
  # As a result, we can use clang to cross-compile but not for sanitizers.
  if [[ ! "$RELEASE_NAME" =~ CentOS.*5\.[[:digit:]] ]]; then
    pushd ../projects
    untar_xz ${THIS_DIR}/compiler-rt-$SOURCE_VERSION.src.tar.xz
    mv compiler-rt-$SOURCE_VERSION.src compiler-rt
    popd
  fi

  popd # tools
  popd # $TARGET_DIR

  # Patches are based on source version. Pass to setup_extracted_package_build function
  # with this var.
  PATCH_DIR=${THIS_DIR}/llvm-${SOURCE_VERSION}-patches

  setup_extracted_package_build $PACKAGE $PACKAGE_VERSION $TARGET_DIR

  PYTHON_EXECUTABLE=$BUILD_DIR/python-$PYTHON_VERSION/bin/python
  if [[ "$OSTYPE" == "darwin"* ]]; then
    PYTHON_EXECUTABLE=/usr/bin/python
    export CXX=
    export CC=
    export CXXFLAGS=
    export LDFLAGS=
  fi

  mkdir -p ${THIS_DIR}/build-$PACKAGE_STRING
  pushd ${THIS_DIR}/build-$PACKAGE_STRING
  local EXTRA_CMAKE_ARGS=
  local LLVM_BUILD_TYPE=Release
  if [[ "$PACKAGE_VERSION" =~ "-asserts" ]]; then
    LLVM_BUILD_TYPE=Release
    EXTRA_CMAKE_ARGS+="-DLLVM_ENABLE_ASSERTIONS=true"
  elif [[ "$PACKAGE_VERSION" =~ "-debug" ]]; then
    LLVM_BUILD_TYPE=Debug
  fi

  if [[ "$ARCH_NAME" == "ppc64le" ]]; then
    LLVM_BUILD_TARGET+="PowerPC"
  elif [[ "$ARCH_NAME" == "aarch64" ]]; then
    LLVM_BUILD_TARGET+="AArch64"
  else
    LLVM_BUILD_TARGET+="X86"
  fi

  # Invoke CMake with the correct configuration
  wrap cmake ${THIS_DIR}/$PACKAGE_STRING.src${PATCH_VERSION} \
      -DCMAKE_BUILD_TYPE=${LLVM_BUILD_TYPE} \
      -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
      -DLLVM_TARGETS_TO_BUILD=$LLVM_BUILD_TARGET \
      -DLLVM_ENABLE_RTTI=ON \
      -DLLVM_ENABLE_TERMINFO=OFF \
      -DLLVM_PARALLEL_COMPILE_JOBS=${BUILD_THREADS:-4} \
      -DLLVM_PARALLEL_LINK_JOBS=${BUILD_THREADS:-4} \
      -DPYTHON_EXECUTABLE=$PYTHON_EXECUTABLE \
      ${EXTRA_CMAKE_ARGS}

  wrap make -j${BUILD_THREADS:-4} install
  popd

  pushd ${THIS_DIR}/build-$PACKAGE_STRING/tools/clang
  wrap make -j${BUILD_THREADS:-4} install
  popd

  finalize_package_build $PACKAGE $PACKAGE_VERSION
}
