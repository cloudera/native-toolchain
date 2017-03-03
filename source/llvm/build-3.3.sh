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

# Builds LLVM 3.3 from source tarballs.

set -eu
set -o pipefail

function build_llvm_33() {
  # Patches are based on source version. Pass to setup_package_build function
  # with this var.
  PATCH_DIR=${THIS_DIR}/llvm-${SOURCE_VERSION}-patches

  setup_package_build $PACKAGE $PACKAGE_VERSION \
      "$THIS_DIR/llvm-${SOURCE_VERSION}.src.${ARCHIVE_EXT}" \
      "llvm-${SOURCE_VERSION}.src" "llvm-${PACKAGE_VERSION}.src"
  LLVM=llvm-$LLVM_VERSION

  # Cleanup possible leftovers
  rm -Rf build-$LLVM
  rm -Rf $LLVM.src

  # Crappy CentOS 5.6 doesnt like us to build Clang, so skip it
  cd tools
  # CLANG
  tar zxf ../../cfe-$SOURCE_VERSION.src.tar.gz
  mv cfe-$SOURCE_VERSION.src clang

  # CLANG Extras
  cd clang/tools
  tar zxf ../../../../clang-tools-extra-$SOURCE_VERSION.src.tar.gz
  mv clang-tools-extra-$SOURCE_VERSION.src extra
  cd ../../

  # COMPILER RT
  cd ../projects
  tar zxf ../../compiler-rt-$SOURCE_VERSION.src.tar.gz
  mv compiler-rt-$SOURCE_VERSION.src compiler-rt
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

  if [[ ! "$OSTYPE" == "darwin"* && $SYSTEM_GCC -eq 0 ]]; then
    EXTRA_CONFIG_ARG="$EXTRA_CONFIG_ARG --with-gcc-toolchain=$BUILD_DIR/gcc-$GCC_VERSION"
  else
    # Reset compile flags on OS X to avoid configuration errors.
    export CXXFLAGS=
    export LDFLAGS=
  fi

  if [[ "$PACKAGE_VERSION" == "3.3" ]]; then
    # Release-asserts build is the default.
    EXTRA_CONFIG_ARG="$EXTRA_CONFIG_ARG --enable-optimized"
  elif [[ "$PACKAGE_VERSION" == "3.3-no-asserts" ]]; then
    EXTRA_CONFIG_ARG="$EXTRA_CONFIG_ARG --enable-optimized --disable-assertions"
  else
    echo "Unexpected LLVM package version ${PACKAGE_VERSION}"
    exit 1
  fi

  wrap ../llvm-$PACKAGE_VERSION.src$PATCH_VERSION/configure \
      --enable-targets=x86_64,cpp --enable-terminfo=no \
      --prefix=$LOCAL_INSTALL --with-pic $EXTRA_CONFIG_ARG \
      --with-extra-ld-options="$LDFLAGS"

  wrap make -j${BUILD_THREADS:-4} REQUIRES_RTTI=1 install

  # Do not forget to install clang as well
  cd tools/clang
  wrap make -j${BUILD_THREADS:-4} REQUIRES_RTTI=1 install

  finalize_package_build $PACKAGE $PACKAGE_VERSION
}
