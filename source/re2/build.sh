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
  # re2 20190301 uses '.tgz' while later releases like 2023-03-01 use '.tar.gz'
  if [[ "${PACKAGE_VERSION}" =~ "2019" ]]; then
    download_dependency $PACKAGE "${PACKAGE_STRING}.tgz" $THIS_DIR
  else
    download_dependency $PACKAGE "${PACKAGE_STRING}.tar.gz" $THIS_DIR
  fi

  setup_package_build $PACKAGE $PACKAGE_VERSION

  # re2 added an abseil-cpp dependency in 2023-06-01. If the CMakeLists.txt exists
  # and references absl, then we need to add that dependency (which is easier to do
  # if we build with CMake).
  if [[ -f CMakeLists.txt ]] && grep -q "absl" CMakeLists.txt ; then
    # Find the location of abslConfig.cmake in abseil-cpp's directory
    # This can't be hard-coded, because it varies across distributions (lib vs lib64).
    ABSL_CONFIG_LOCATION=$(find $BUILD_DIR/abseil-cpp-${ABSEIL_CPP_VERSION} -name 'abslConfig.cmake')
    [[ -f $ABSL_CONFIG_LOCATION ]]
    ABSL_CONFIG_DIR=$(dirname ${ABSL_CONFIG_LOCATION})

    # Need separate builds for static library versus shared library
    rm -rf build_static
    mkdir build_static
    pushd build_static
    wrap cmake -DCMAKE_BUILD_TYPE=RELEASE -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
         -Dabsl_DIR=$ABSL_CONFIG_DIR ..
    wrap make VERBOSE=1 -j${BUILD_THREADS:-4}
    wrap make install
    popd

    rm -rf build_shared
    mkdir build_shared
    pushd build_shared
    wrap cmake -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=RELEASE \
         -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
         -Dabsl_DIR=$ABSL_CONFIG_DIR ..
    wrap make VERBOSE=1 -j${BUILD_THREADS:-4}
    wrap make install
    popd
  else
    # For some reason, re2 doesn't play nice with prefix installations and other
    # typical configuration parameters
    EXTENSION=
    if [[ "$OSTYPE" == "darwin"* ]]; then
      EXTENSION=.bak
    fi
    sed -i $EXTENSION 's/CXXFLAGS=-Wall/CXXFLAGS+=-Wall/' Makefile
    sed -i $EXTENSION 's/LDFLAGS=-pthread/LDFLAGS+=-pthread/' Makefile
    sed -i $EXTENSION 's/CXX=g\+\+/CXX?=g\+\+/' Makefile
    sed -i $EXTENSION 's/prefix=\/usr/prefix?=\/usr/' Makefile
    prefix=$LOCAL_INSTALL wrap make VERBOSE=1 -j${BUILD_THREADS:-4} install
  fi

  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
