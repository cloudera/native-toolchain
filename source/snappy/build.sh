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

  # Snappy's CMake builds either shared or static but not both. Build each separately.
  # Adds -fno-omit-frame-pointer to enable frame pointers. Snappy uses CMAKE_CXX_FLAGS
  # (instead of CMAKE_C_FLAGS) in the builds. Flags set in CXXFLAGS env variable will be
  # ignored if CMAKE_CXX_FLAGS is defined. We should add $CXXFLAGS in the flags as well.
  mkdir -p build_shared
  pushd build_shared
  wrap cmake -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=RELEASE \
             -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
             -DCMAKE_CXX_FLAGS="$CXXFLAGS -fno-omit-frame-pointer" ..
  wrap make VERBOSE=1 -C . -j${BUILD_THREADS:-4} install
  popd

  mkdir -p build_static
  pushd build_static
  wrap cmake -DCMAKE_BUILD_TYPE=RELEASE -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
             -DCMAKE_CXX_FLAGS="$CXXFLAGS -fno-omit-frame-pointer" ..
  wrap make VERBOSE=1 -C . -j${BUILD_THREADS:-4} install
  popd

  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
