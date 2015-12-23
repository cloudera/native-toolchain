#!/usr/bin/env bash
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

set -e
set -u
set -o pipefail

# This script exports the following variables:
#
#  - CC, CXX, CXXFLAGS, CFLAGS, LDFLAGS
#  - COMPILER / COMPILER_VERSION
#  - FAIL_ON_PUBLISH
#  - PUBLISH_DEPENDENCIES
#  - DEBUG
#  - PRODUCTION
#  - SYSTEM_GCC
#  - CLEAN
#  - RELEASE_NAME
#  - MACOSX_DEPLOYMENT_TARGET -- only on Mac OS X
#  - ARCH_FLAGS

# If set to 1 will use -x flag in bash and print the output to stdout and write
# it to the log file. If set to 0 only writes to the log file.
: ${DEBUG=0}
export DEBUG

# If set to 1, will fail the build if the artifacts could not be published.
: ${FAIL_ON_PUBLISH=0}
export FAIL_ON_PUBLISH

# If set to 1, the script will upload the artifacts to the internal artifactory
: ${PUBLISH_DEPENDENCIES=0}
export PUBLISH_DEPENDENCIES

# A flag that can be used to trigger particular behavior. PRODUCTION=1 is how
# the toolchain is used for packaging native products.
: ${PRODUCTION=1}
export PRODUCTION

# Clean the complete build
: ${CLEAN=0}
export CLEAN

# Flag to determine the system compiler is used
: ${SYSTEM_GCC=0}
export SYSTEM_GCC

: ${GCC_VERSION=4.9.2}
export GCC_VERSION

# Determine the number of build threads
BUILD_THREADS=$(getconf _NPROCESSORS_ONLN)
export BUILD_THREADS

# SOURCE DIR for the current script
export SOURCE_DIR="$( cd "$( dirname "$0" )" && pwd )"

if [[ $DEBUG -eq 1 ]]; then
  set -x
fi

# Load functions
source $SOURCE_DIR/functions.sh

# Make sure the necessary file system layout exists
prepare_build_dir

if [[ $SYSTEM_GCC -eq 0 ]]; then
  COMPILER="gcc"
  COMPILER_VERSION=$GCC_VERSION
else
  COMPILER="gcc"
  COMPILER_VERSION="system"
fi

export COMPILER
export COMPILER_VERSION

################################################################################
# Prepare compiler and linker commands. This will set the typical environment
# variables. In this case these are:
#
#  - CFLAGS
#  - CXXFLAGS
#  - LDFLAGS
#
################################################################################

# ARCH_FLAGS are used to convey architectur dependent flags that should
# be obbeyed by libraries explicitly needing this information.
ARCH_FLAGS="-mno-avx2"

# Check Platform and build the correct release name. The RELEASE_NAME is used
# when publishing the artifacts to the artifactory.
if [[ "$OSTYPE" =~ ^linux ]]; then
  RELEASE_NAME=`lsb_release -r -i`
elif [[ "$OSTYPE" == "darwin"* ]]; then
  RELEASE_NAME="OSX-$(sw_vers -productVersion)"
  DARWIN_VERSION=`sw_vers -productVersion`

  # The deployment target environment variable is needed to silence warning and
  # errors on OS X wrt rpath settings and libary dependencies.
  export MACOSX_DEPLOYMENT_TARGET=$(echo $DARWIN_VERSION| sed -E 's/(10.[0-9]+).*/\1/')

  # Setting the C++ stlib to libstdc++ on Mac instead of the default libc++
  ARCH_FLAGS="${ARCH_FLAGS} -stdlib=libstdc++"
fi

export ARCH_FLAGS
if [[ $SYSTEM_GCC -eq 0 ]]; then
  # Build GCC that is used to build LLVM
  $SOURCE_DIR/source/gcc/build.sh

  # Stage one is done, we can upgrade our compiler
  CC="$BUILD_DIR/gcc-$GCC_VERSION/bin/gcc"
  CXX="$BUILD_DIR/gcc-$GCC_VERSION/bin/g++"

  # Upgrade rpath variable to catch current library location and possible future location
  if [[ "$OSTYPE" == "darwin"* ]]; then
    FULL_RPATH="-Wl,-rpath,$BUILD_DIR/gcc-$GCC_VERSION/lib,-rpath,'\$ORIGIN/../lib'"
  else
    FULL_RPATH="-Wl,-rpath,$BUILD_DIR/gcc-$GCC_VERSION/lib64,-rpath,'\$ORIGIN/../lib64'"
  fi
  FULL_RPATH="${FULL_RPATH},-rpath,'\$ORIGIN/../lib'"

  FULL_LPATH="-L$BUILD_DIR/gcc-$GCC_VERSION/lib64"
  LDFLAGS="$ARCH_FLAGS $FULL_RPATH $FULL_LPATH"
  CXXFLAGS="$ARCH_FLAGS -static-libstdc++ -fPIC -O3 -m64"
else
  CXX="g++ -stdlib=libstdc++"
  LDFLAGS=""
  CXXFLAGS="-fPIC -O3 -m64"
fi

CFLAGS="-fPIC -O3 -m64"


# List of export variables
export CC
export CFLAGS
export CLEAN
export COMPILER
export COMPILER_VERSION
export CXX
export CXXFLAGS
export DEBUG
export LDFLAGS
export RELEASE_NAME
