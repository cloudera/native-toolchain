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

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR

if needs_build_package ; then
  # Download the dependency from S3
  download_dependency $PACKAGE "${PACKAGE_STRING}.tar.gz" $THIS_DIR

  setup_package_build $PACKAGE $PACKAGE_VERSION

  GFLAGS_CMAKE_CONF_DIR=$BUILD_DIR/gflags-$GFLAGS_VERSION/lib/cmake/gflags

  COMMON_GLOG_CMAKE_FLAGS="-Dgflags_DIR=$GFLAGS_CMAKE_CONF_DIR \
    -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL -DCMAKE_BUILD_TYPE=RELEASE -DWITH_TLS=OFF"

  # glog's CMake builds either a shared or a static library but not both. Build each one
  # separately.
  rm -rf build_shared
  mkdir build_shared
  pushd build_shared
  wrap cmake -DBUILD_SHARED_LIBS=ON $COMMON_GLOG_CMAKE_FLAGS ..
  wrap make VERBOSE=1 -j${BUILD_THREADS:-4} install
  popd

  rm -rf build_static
  mkdir build_static
  pushd build_static
  wrap cmake -DBUILD_SHARED_LIBS=OFF $COMMON_GLOG_CMAKE_FLAGS ..
  wrap make VERBOSE=1 -j${BUILD_THREADS:-4} install
  popd

  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
