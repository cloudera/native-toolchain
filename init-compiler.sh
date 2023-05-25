#!/usr/bin/env bash
# Copyright 2017 Cloudera Inc.
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

set -e
set -u
set -o pipefail

# This script sets up the compiler and compilation tools, and exports the following
# environment variables:
#
#  - CC, CXX, CXXFLAGS, CFLAGS, LDFLAGS
#  - ARCH_FLAGS

################################################################################
# Prepare compiler and linker commands. This will set the typical environment
# variables.
################################################################################

# OS X doesn't use binutils.
if [[ "$OSTYPE" != "darwin"* ]]; then
  # Build binutils against the system OS libraries. We only need the executables,
  # and it is hard to set RPATH properly for binutils, so it is better to avoid
  # using our custom gcc/libstdc++.
  "$SOURCE_DIR"/source/binutils/build.sh
  # In order to build GCC with LTO (which is only for improving the GCC binary
  # itself), GCC needs a new binutils. This puts the new binutils on the path
  # for the GCC compilation and subsequent builds.
  PATH="$BUILD_DIR/binutils-$BINUTILS_VERSION/bin:$PATH"
fi

################################################################################
# Build GDB
################################################################################
# Build GDB against the system OS libraries. This is the same issue as binutils.
# We only need the executables and it is hard to set the RPATH properly.
# It is simpler to compile with the OS compiler/packages.
GDB_VERSION=12.1 "$SOURCE_DIR"/source/gdb/build.sh

if [[ "$OSTYPE" =~ ^linux ]]; then
  # ARCH_FLAGS are used to convey architecture dependent flags that should
  # be obeyed by libraries explicitly needing this information.
  if [[ "$ARCH_NAME" == "ppc64le" ]]; then
    ARCH_FLAGS="-mvsx -maltivec"
  elif [[ "$ARCH_NAME" == "aarch64" ]]; then
    ARCH_FLAGS="-march=armv8-a"
  else
    # x86_64
    ARCH_FLAGS="-m64 -mno-avx2"
  fi
  ARCH_CXXFLAGS=""
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # Setting the C++ stlib to libstdc++ on Mac instead of the default libc++
  ARCH_CXXFLAGS="-stdlib=libstdc++"
fi

export SYSTEM_GCC_VERSION=$(gcc -dumpversion)
if [[ $SYSTEM_GCC -eq 0 ]]; then
  if [[ $USE_CCACHE -ne 0 ]]; then
    CC=$(setup_ccache $(which gcc))
    CXX=$(setup_ccache $(which g++))
    export PATH="$(dirname $CC):$(dirname $CXX):$PATH"
  fi
  # Build GCC that is used to build LLVM
  $SOURCE_DIR/source/gcc/build.sh

  # Stage one is done, we can upgrade our compiler
  CC="$BUILD_DIR/gcc-$GCC_VERSION/bin/gcc"
  CXX="$BUILD_DIR/gcc-$GCC_VERSION/bin/g++"

  # Add rpath to all binaries we produce that points to the ../lib/ subdirectory relative
  # to the output binaries or libraries. Need to include versions with both $ORIGIN and
  # $$ORIGIN to work around autotools and CMake projects inconsistently escaping LDFLAGS
  # values. We always get the expected "$ORIGIN/" rpaths in produced binaries, but we also
  # get a bad rpath in each binary: either starting with "$$ORIGIN/" or "RIGIN/". The bad
  # rpaths are ignored by the dynamic linker and are harmless.
  if [[ "$OSTYPE" == "darwin"* ]]; then
    FULL_RPATH="-Wl,-rpath,'\$ORIGIN/../lib',-rpath,'\$\$ORIGIN/../lib'"
  else
    FULL_RPATH="-Wl,-rpath,'\$ORIGIN/../lib64',-rpath,'\$\$ORIGIN/../lib64'"
  fi
  FULL_RPATH="${FULL_RPATH},-rpath,'\$ORIGIN/../lib',-rpath,'\$\$ORIGIN/../lib'"

  FULL_LPATH="-L$BUILD_DIR/gcc-$GCC_VERSION/lib64"
  LDFLAGS="$ARCH_FLAGS $FULL_RPATH $FULL_LPATH"
else
  LDFLAGS=""
fi
# -g1 enables basic debug information for backtraces
# -gz enables compression of debug information
# -gdwarf-4 sets the DWARF version to 4. It is better to be explicit about the DWARF
#     version because newer compilers default to DWARF 5.
CFLAGS="$ARCH_FLAGS -fPIC -O3 -g1 -gz -gdwarf-4"
CXXFLAGS="$CFLAGS $ARCH_CXXFLAGS"
if [[ $USE_CCACHE -ne 0 ]]; then
  CC=$(setup_ccache $CC)
  CXX=$(setup_ccache $CXX)
  export PATH="$(dirname $CC):$(dirname $CXX):$PATH"
fi

# List of export variables after configuring gcc
export ARCH_FLAGS
export CC
export CXX
export CXXFLAGS
export LDFLAGS
export CFLAGS

# Build and export toolchain cmake
if [[ $SYSTEM_CMAKE -eq 0 ]]; then
  $SOURCE_DIR/source/cmake/build.sh
  CMAKE_BIN=$BUILD_DIR/cmake-$CMAKE_VERSION/bin/
  PATH=$CMAKE_BIN:$PATH
fi
