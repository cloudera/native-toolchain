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

# Exit on non-true return value
set -e
# Exit on reference to uninitialized variable
set -u
set -o pipefail

# Set up the environment configuration.
source ./init.sh

if [[ "$DOWNLOAD_CCACHE" -ne 0 ]]; then
  download_ccache
fi

# Configure the compiler/linker flags, bootstrapping tools if necessary.
source ./init-compiler.sh

################################################################################
# How to add new versions to the toolchain:
#
#   * Make sure the build script is ready to build the new version.
#   * Find the libary in the list below and create new line that follows the
#     pattern: LIBRARYNAME_VERSION=Version $SOURCE_DIR/source/LIBRARYNAME/build.sh
#   * Multiple versions are allowed, but versions that are no longer in use
#     should be removed.
################################################################################
################################################################################
# Boost
################################################################################
BOOST_VERSION=1.74.0-p1 $SOURCE_DIR/source/boost/build.sh

################################################################################
# Build BZip2
################################################################################
BZIP2_VERSION=1.0.8-p2 $SOURCE_DIR/source/bzip2/build.sh

################################################################################
# Build Python
################################################################################
export BZIP2_VERSION=1.0.8-p2
# For now, provide both Python 2 and 3 until we can switch over to Python 3.
PYTHON_VERSION=2.7.16 $SOURCE_DIR/source/python/build.sh
PYTHON_VERSION=3.7.16 $SOURCE_DIR/source/python/build.sh

export -n BZIP2_VERSION
################################################################################
# LLVM
################################################################################
# Build LLVM 3.7+ with and without assertions. For LLVM 3.7+, the default is a
# release build with no assertions.
(
  LLVM_VERSION=5.0.1-p7 $SOURCE_DIR/source/llvm/build.sh
  LLVM_VERSION=5.0.1-asserts-p7 $SOURCE_DIR/source/llvm/build.sh
)

################################################################################
# Build protobuf
################################################################################
PROTOBUF_VERSION=3.14.0 $SOURCE_DIR/source/protobuf/build.sh
# Impala Clang builds hit a micro redefinition compiling error and symbol related
# issue in linking with protobuf 3.14.0. Two patches were created to fix these
# Clang compatibility issues.
# 3.14.0-clangcompat-p2 should be used for Impala Clang builds.
PROTOBUF_VERSION=3.14.0-clangcompat-p2 $SOURCE_DIR/source/protobuf/build.sh

################################################################################
# Build libev
################################################################################
LIBEV_VERSION=4.20-p1 $SOURCE_DIR/source/libev/build.sh

################################################################################
# Build crcutil
################################################################################
CRCUTIL_VERSION=2903870057d2f1f109b245650be29e856dc8b646\
  $SOURCE_DIR/source/crcutil/build.sh

################################################################################
# Build ZLib
################################################################################
ZLIB_VERSION=1.2.13 $SOURCE_DIR/source/zlib/build.sh

################################################################################
# Build Cloudflare ZLib
################################################################################
CLOUDFLAREZLIB_VERSION=9e601a3f37 $SOURCE_DIR/source/cloudflarezlib/build.sh

################################################################################
# Build Thrift
#  * depends on boost, zlib and openssl
################################################################################
export BOOST_VERSION=1.74.0-p1
export ZLIB_VERSION=1.2.13
export PYTHON_VERSION=2.7.16

THRIFT_VERSION=0.11.0-p5 $SOURCE_DIR/source/thrift/build.sh
THRIFT_VERSION=0.16.0-p6 $SOURCE_DIR/source/thrift/build.sh

export -n BOOST_VERSION
export -n ZLIB_VERSION
export -n PYTHON_VERSION

################################################################################
# gflags
################################################################################
GFLAGS_VERSION=2.2.0-p2 $SOURCE_DIR/source/gflags/build.sh

################################################################################
# Build gperftools
################################################################################
GPERFTOOLS_VERSION=2.8.1-p1 $SOURCE_DIR/source/gperftools/build.sh
GPERFTOOLS_VERSION=2.10 $SOURCE_DIR/source/gperftools/build.sh

################################################################################
# Build glog
################################################################################
GFLAGS_VERSION=2.2.0-p2 GLOG_VERSION=0.3.5-p3 $SOURCE_DIR/source/glog/build.sh

################################################################################
# Build gtest
################################################################################
GTEST_VERSION=1.6.0 $SOURCE_DIR/source/gtest/build.sh

# New versions of gtest are named googletest
GOOGLETEST_VERSION=1.8.0 $SOURCE_DIR/source/googletest/build.sh

################################################################################
# Build Snappy
################################################################################
SNAPPY_VERSION=1.1.8 $SOURCE_DIR/source/snappy/build.sh

################################################################################
# Build Lz4
################################################################################
LZ4_VERSION=1.9.3 $SOURCE_DIR/source/lz4/build.sh

################################################################################
# Build Zstd
################################################################################
ZSTD_VERSION=1.5.2 $SOURCE_DIR/source/zstd/build.sh

################################################################################
# Build re2
################################################################################
RE2_VERSION=20190301 $SOURCE_DIR/source/re2/build.sh

################################################################################
# Build Ldap
################################################################################
OPENLDAP_VERSION=2.4.47 $SOURCE_DIR/source/openldap/build.sh

################################################################################
# Build Avro
################################################################################
AVRO_VERSION=1.7.4-p5 $SOURCE_DIR/source/avro/build.sh
# Build a new version as well
(
  export BOOST_VERSION=1.74.0-p1
  AVRO_VERSION=1.11.1-p1 $SOURCE_DIR/source/avro/build-cpp.sh
)

################################################################################
# Build Rapidjson
################################################################################
RAPIDJSON_VERSION=1.1.0 $SOURCE_DIR/source/rapidjson/build.sh

################################################################################
# Build Libunwind
################################################################################
LIBUNWIND_VERSION=1.7.2-p1 $SOURCE_DIR/source/libunwind/build.sh

################################################################################
# Build Breakpad
################################################################################
BREAKPAD_VERSION=e09741c609dcd5f5274d40182c5e2cc9a002d5ba-p2 $SOURCE_DIR/source/breakpad/build.sh

################################################################################
# Build Flatbuffers
################################################################################
FLATBUFFERS_VERSION=1.9.0-p1 $SOURCE_DIR/source/flatbuffers/build.sh

################################################################################
# Build Kudu
################################################################################
(
  export BOOST_VERSION=1.74.0-p1
  export KUDU_VERSION=e742f86f6d
  if $SOURCE_DIR/source/kudu/build.sh is_supported_platform; then
    $SOURCE_DIR/source/kudu/build.sh build
  else
    build_fake_package kudu
  fi
)

################################################################################
# Build TPC-H
################################################################################
TPC_H_VERSION=2.17.0 $SOURCE_DIR/source/tpc-h/build.sh

################################################################################
# Build TPC-DS
################################################################################
TPC_DS_VERSION=2.1.0-p1 $SOURCE_DIR/source/tpc-ds/build.sh

################################################################################
# Build ORC
################################################################################
(
  export LZ4_VERSION=1.9.3
  export PROTOBUF_VERSION=3.14.0
  export SNAPPY_VERSION=1.1.8
  export ZLIB_VERSION=1.2.13
  export ZSTD_VERSION=1.5.2
  export GOOGLETEST_VERSION=1.8.0
  ORC_VERSION=1.7.9-p10 $SOURCE_DIR/source/orc/build.sh
)

################################################################################
# CCTZ
################################################################################
CCTZ_VERSION=2.2 $SOURCE_DIR/source/cctz/build.sh

################################################################################
# JWT-CPP
################################################################################
JWT_CPP_VERSION=0.5.0 $SOURCE_DIR/source/jwt-cpp/build.sh

################################################################################
# ARROW
################################################################################
ARROW_VERSION=9.0.0-p2 $SOURCE_DIR/source/arrow/build.sh

# CURL
################################################################################
CURL_VERSION=7.78.0 $SOURCE_DIR/source/curl/build.sh

# CALLONCEHACK
################################################################################
CALLONCEHACK_VERSION=1.0.0 $SOURCE_DIR/source/calloncehack/build.sh

################################################################################
# Build hadoop native client libraries
################################################################################
if [[ "$ARCH_NAME" == "aarch64" ]]; then
  (
    export PROTOBUF_VERSION=3.14.0
    export SNAPPY_VERSION=1.1.8
    export ZLIB_VERSION=1.2.13
    export ZSTD_VERSION=1.5.2
    HADOOP_CLIENT_VERSION=3.3.6 $SOURCE_DIR/source/hadoop-client/build.sh
  )
fi
