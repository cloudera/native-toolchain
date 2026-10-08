#!/usr/bin/env bash
# Copyright 2016 Cloudera Inc.
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
  add_gcc_to_ld_library_path

  # Build with CMake (rather than autotools) so that a CMake package config
  # (protobuf-config.cmake) is installed. Consumers such as gRPC resolve
  # protobuf via find_package(Protobuf CONFIG), which requires this file.
  rm -rf build_static
  mkdir build_static
  pushd build_static
  # Protobuf 3.21+ moved its CMake project to the repository root and made
  # abseil a mandatory dependency; point it at our own build instead of
  # letting it fetch one from the network.
  ABSL_CONFIG_LOCATION=$(find $BUILD_DIR/abseil-cpp-${ABSEIL_CPP_VERSION} -name 'abslConfig.cmake')
  [[ -f $ABSL_CONFIG_LOCATION ]]
  ABSL_CONFIG_DIR=$(dirname ${ABSL_CONFIG_LOCATION})
  wrap cmake .. -DCMAKE_BUILD_TYPE=RELEASE -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_CXX_STANDARD=17 \
        -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_BUILD_SHARED_LIBS=OFF \
        -Dabsl_DIR=$ABSL_CONFIG_DIR -Dprotobuf_LOCAL_DEPENDENCIES_ONLY=ON \
        -DZLIB_ROOT=$BUILD_DIR/zlib-${ZLIB_VERSION}
  wrap make VERBOSE=1 -j${BUILD_THREADS:-4}
  wrap make install
  popd

  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
