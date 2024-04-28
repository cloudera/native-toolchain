#!/usr/bin/env bash
# Copyright 2023 Cloudera Inc.
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
  # Download the dependency from S3
  download_dependency $PACKAGE "avro-src-${PACKAGE_VERSION}.tar.gz" $THIS_DIR

  setup_package_build $PACKAGE $PACKAGE_VERSION

  BOOST_ROOT="${BUILD_DIR}"/boost-"${BOOST_VERSION}"

  cd lang/c++
  mkdir -p build
  cd build
  wrap cmake -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
    -DBOOST_ROOT=${BOOST_ROOT} \
    ..
  wrap make VERBOSE=1 -C . -j${BUILD_THREADS:-4}

  # Different versions of CMake produce different locations for the avro-c.pc file
  if [[ -e avro-c.pc ]]; then
    cp avro-c.pc src/
  fi

  wrap make -C . -j${BUILD_THREADS:-4} install
  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
