#!/usr/bin/env bash
# Copyright 2018 Cloudera Inc.
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

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR

if needs_build_package ; then
  download_dependency $PACKAGE "orc-${PACKAGE_VERSION}.tar.gz" $THIS_DIR
  setup_package_build $PACKAGE $PACKAGE_VERSION

  # ORC 1.5+ uses *_HOME environment variables to find dependencies.
  export LZ4_HOME=$BUILD_DIR/lz4-${LZ4_VERSION}
  export PROTOBUF_HOME=$BUILD_DIR/protobuf-${PROTOBUF_VERSION}
  export SNAPPY_HOME=$BUILD_DIR/snappy-${SNAPPY_VERSION}
  export ZLIB_HOME=$BUILD_DIR/zlib-${ZLIB_VERSION}
  export ZSTD_HOME=$BUILD_DIR/zstd-${ZSTD_VERSION}

  # The LZ4 lib dir name varies by distribution. Check the Debian/Ubuntu location and
  # fall back to the lib64 location used by SLES and CentOS.
  LZ4_LIB_DIR=$BUILD_DIR/lz4-${LZ4_VERSION}/lib
  if [[ ! -d "${LZ4_LIB_DIR}" ]]; then
    LZ4_LIB_DIR=$BUILD_DIR/lz4-${LZ4_VERSION}/lib64
  fi

  wrap cmake -DBUILD_SHARED_LIBS=ON -DBUILD_JAVA=OFF -DBUILD_LIBHDFSPP=OFF\
      -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL -DCMAKE_BUILD_TYPE=RELWITHDEBINFO \
      -DBUILD_CPP_TESTS=OFF
  wrap make VERBOSE=1 -j${BUILD_THREADS:-4} install
  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
