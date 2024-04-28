#!/usr/bin/env bash
# Copyright 2024 Cloudera Inc.
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
  # Google Benchmark has tarballs like "benchmark-VERSION.tar.gz" that extract
  # to "benchmark-VERSION"
  TARBALL_BASE_NAME="benchmark-${PACKAGE_VERSION}"
  download_dependency $PACKAGE "${TARBALL_BASE_NAME}.tar.gz" $THIS_DIR

  # Rename the directory from benchmark-VERSION to googlebenchmark-VERSION
  setup_package_build $PACKAGE $PACKAGE_VERSION "${TARBALL_BASE_NAME}.tar.gz" \
      "$TARBALL_BASE_NAME" $PACKAGE_STRING

  rm -rf build_static
  mkdir build_static
  pushd build_static
  wrap cmake -DCMAKE_BUILD_TYPE=RELEASE -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
       -DBENCHMARK_ENABLE_TESTING=OFF -DBENCHMARK_ENABLE_LIBPFM=ON \
       -DPFM_ROOT=$BUILD_DIR/libpfm-${LIBPFM_VERSION} ..
  wrap make VERBOSE=1 -j${BUILD_THREADS:-4}
  wrap make install
  popd

  rm -rf build_shared
  mkdir build_shared
  pushd build_shared
  wrap cmake -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=RELEASE \
       -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
       -DBENCHMARK_ENABLE_TESTING=OFF -DBENCHMARK_ENABLE_LIBPFM=ON \
       -DPFM_ROOT=$BUILD_DIR/libpfm-${LIBPFM_VERSION} ..
  wrap make VERBOSE=1 -j${BUILD_THREADS:-4}
  wrap make install
  popd

  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
