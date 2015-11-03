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

# cleans and rebuilds thirdparty/. The Impala build environment must be set up
# by bin/impala-config.sh before running this script.

# Exit on non-true return value
set -e
# Exit on reference to uninitialized variable
set -u
set -o pipefail

# The init.sh script contains all the necessary logic to setup the environment
# for the build process. This includes setting the right compiler and linker
# flags.
source $SOURCE_DIR/init.sh

################################################################################
# How to add new versions to the toolchain:
#
#   * Make sure the build script is ready to build the new version.
#   * Find the libary in the list below and create new line that follows the
#     pattern: LIBRARYNAME_VERSION=Version $SOURCE_DIR/source/LIBRARYNAME/build.sh
#
#  WARNING: Once a library has been rolled out to production, it cannot be
#  removed, but only new versions can be added. Make sure that the library
#  and version you want to add works as expected.
################################################################################

################################################################################
# Boost
################################################################################
BOOST_VERSION=1.57.0 $SOURCE_DIR/source/boost/build.sh

################################################################################
# Build Python
################################################################################
if [[ ! "$OSTYPE" == "darwin"* ]]; then
  PYTHON_VERSION=2.7.10 $SOURCE_DIR/source/python/build.sh
fi

################################################################################
# Build CMake
################################################################################
if [[ ! "$OSTYPE" == "darwin"* ]]; then
  CMAKE_VERSION=3.2.3 $SOURCE_DIR/source/cmake/build.sh
fi

################################################################################
# LLVM
################################################################################

# Build Default LLVM
LLVM_VERSION=3.3-p1 $SOURCE_DIR/source/llvm/build.sh

# CentOS 5 can't build trunk LLVM due to missing perf counter
if [[ ! "$RELEASE_NAME" =~ CentOS.*5\.[[:digit:]] ]]; then
  # Build LLVM 3.7.0
  LLVM_VERSION=3.7.0 $SOURCE_DIR/source/llvm/build.sh
fi

################################################################################
# SASL
################################################################################
if [[ ! "$OSTYPE" == "darwin"* ]]; then
  $SOURCE_DIR/source/cyrus-sasl/build.sh
else
  CYRUS_SASL_VERSION=2.1.26 $SOURCE_DIR/source/cyrus-sasl/build.sh
fi

################################################################################
# Build libevent
################################################################################
$SOURCE_DIR/source/libevent/build.sh

################################################################################
# Build OpenSSL - this is not intended for production use of Impala.
# Libraries that depend on OpenSSL will only use it if PRODUCTION=1.
################################################################################
OPENSSL_VERSION=1.0.1p $SOURCE_DIR/source/openssl/build.sh

################################################################################
# Thrift
#  * depends on boost
#  * depends on libevent
################################################################################
if [[ ! "$OSTYPE" == "darwin"* ]]; then
  THRIFT_VERSION=0.9.0-p2 $SOURCE_DIR/source/thrift/build.sh
  THRIFT_VERSION=0.9.0-p4 $SOURCE_DIR/source/thrift/build.sh
else
  THRIFT_VERSION=0.9.2-p2 $SOURCE_DIR/source/thrift/build.sh
fi

################################################################################
# gflags
################################################################################
GFLAGS_VERSION=2.0 $SOURCE_DIR/source/gflags/build.sh

################################################################################
# Build pprof
################################################################################
GPERFTOOLS_VERSION=2.3 $SOURCE_DIR/source/gperftools/build.sh
GPERFTOOLS_VERSION=2.0-p1 $SOURCE_DIR/source/gperftools/build.sh

################################################################################
# Build glog
################################################################################
GLOG_VERSION=0.3.2-p1 $SOURCE_DIR/source/glog/build.sh

################################################################################
# Build gtest
################################################################################
GTEST_VERSION=1.6.0 $SOURCE_DIR/source/gtest/build.sh

################################################################################
# Build Snappy
################################################################################
SNAPPY_VERSION=1.0.5 $SOURCE_DIR/source/snappy/build.sh

################################################################################
# Build Lz4
################################################################################
LZ4_VERSION=svn $SOURCE_DIR/source/lz4/build.sh

################################################################################
# Build re2
################################################################################
RE2_VERSION=20130115 $SOURCE_DIR/source/re2/build.sh
RE2_VERSION=20130115-p1 $SOURCE_DIR/source/re2/build.sh

################################################################################
# Build Ldap
################################################################################
OPENLDAP_VERSION=2.4.25 $SOURCE_DIR/source/openldap/build.sh

################################################################################
# Build Avro
################################################################################
AVRO_VERSION=1.7.4-p3 $SOURCE_DIR/source/avro/build.sh

################################################################################
# Build Rapidjson
################################################################################
RAPIDJSON_VERSION=0.11 $SOURCE_DIR/source/rapidjson/build.sh

################################################################################
# Build ZLib
################################################################################
ZLIB_VERSION=1.2.8 $SOURCE_DIR/source/zlib/build.sh

################################################################################
# Build BZip2
################################################################################
BZIP2_VERSION=1.0.6-p1 $SOURCE_DIR/source/bzip2/build.sh

################################################################################
# Build GDB
################################################################################
if [[ ! "$RELEASE_NAME" =~ CentOS.*5\.[[:digit:]] ]]; then
  GDB_VERSION=7.9.1 $SOURCE_DIR/source/gdb/build.sh
fi

################################################################################
# Build Breakpad
################################################################################
BREAKPAD_VERSION=20150612-p1 $SOURCE_DIR/source/breakpad/build.sh
