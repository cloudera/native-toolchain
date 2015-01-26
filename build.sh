#!/usr/bin/env bash
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

# cleans and rebuilds thirdparty/. The Impala build environment must be set up
# by bin/impala-config.sh before running this script.

# Exit on non-true return value
set -e
# Exit on reference to uninitialized variable
set -u


# SOURCE DIR for the current script
export SOURCE_DIR="$( cd "$( dirname "$0" )" && pwd )"

# Load all common version numbers for the thirdparty dependencies
source $SOURCE_DIR/platform.sh

export TOOLCHAIN_DEST_PATH=/opt/bin-toolchain

# Clean the complete build
: ${CLEAN=0}

# Package flag when not suing the system GCC
: ${WITH_GCC=""}
export WITH_GCC=$WITH_GCC

if [ $CLEAN -eq 1 ]; then
  echo "Cleaning.."
  git clean -fdx $SOURCE_DIR
fi

# Destination directory for build
mkdir -p $SOURCE_DIR/build
export BUILD_DIR=$SOURCE_DIR/build

# Create a check directory containing a sentry file for each package
mkdir -p $SOURCE_DIR/check

# Now, start building the compilers first
# Build GCC that is used to build LLVM
$SOURCE_DIR/source/gcc/build.sh

: ${SYSTEM_GCC=0}

if [[ $SYSTEM_GCC -eq 0 ]]; then
  # Stage one is done, we can upgrade our compiler
  export CC="$BUILD_DIR/gcc-$GCC_VERSION/bin/gcc"
  export CXX="$BUILD_DIR/gcc-$GCC_VERSION/bin/g++"

  # Upgrade rpath variable to catch current library location and possible future location
  FULL_RPATH="-Wl,-rpath,$BUILD_DIR/gcc-$GCC_VERSION/lib64,-rpath,'\$ORIGIN/../lib64',-rpath,'$TOOLCHAIN_DEST_PATH/gcc-$GCC_VERSION'"
  FULL_LPATH="-L$BUILD_DIR/gcc-$GCC_VERSION/lib64"
  export CFLAGS="-fPIC"
  export CXXFLAGS="-static-libstdc++ -static-libgcc -std=c++11 -fPIC"
  export LDFLAGS="$FULL_RPATH $FULL_LPATH"
  export WITH_GCC="+gcc"
fi

# Build LLVM
$SOURCE_DIR/source/llvm/build.sh

# Once this is done proceed with the regular thirdparty build
cd $SOURCE_DIR

################################################################################
# SASL
################################################################################

$SOURCE_DIR/source/cyrus-sasl/build.sh

################################################################################
# Boost
################################################################################

$SOURCE_DIR/source/boost/build.sh

################################################################################
# Build libevent
################################################################################
$SOURCE_DIR/source/libevent/build.sh

################################################################################
# Thrift
#  * depends on boost
#  * depends on libevent
################################################################################
$SOURCE_DIR/source/thrift/build.sh

################################################################################
# gflags
################################################################################
$SOURCE_DIR/source/gflags/build.sh

################################################################################
# Build pprof
################################################################################
$SOURCE_DIR/source/gperftools/build.sh

################################################################################
# Build glog
################################################################################
$SOURCE_DIR/source/glog/build.sh

################################################################################
# Build gtest
################################################################################
$SOURCE_DIR/source/gtest/build.sh

################################################################################
# Build Snappy
################################################################################
$SOURCE_DIR/source/snappy/build.sh

################################################################################
# Build Lz4
################################################################################
$SOURCE_DIR/source/lz4/build.sh

################################################################################
# Build re2
################################################################################
$SOURCE_DIR/source/re2/build.sh

################################################################################
# Build Ldap
################################################################################
$SOURCE_DIR/source/openldap/build.sh

################################################################################
# Build Avro
################################################################################
$SOURCE_DIR/source/avro/build.sh

################################################################################
# Build Rapidjson
################################################################################
$SOURCE_DIR/source/rapidjson/build.sh

################################################################################
# Build ZLib
################################################################################
$SOURCE_DIR/source/zlib/build.sh

################################################################################
# Build BZip2
################################################################################
$SOURCE_DIR/source/bzip2/build.sh
