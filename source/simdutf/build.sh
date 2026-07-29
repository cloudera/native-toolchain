#!/usr/bin/env bash
# Copyright 2026 Cloudera Inc.
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

  # simdutf's CMake builds either a shared or a static library, but not both.
  # Build each separately so dynamically-linked Impala builds are supported too.
  for lib_type in shared static ; do
    if [[ "$lib_type" == "shared" ]]; then
      SHARED_LIBS=ON
    else
      SHARED_LIBS=OFF
    fi

    rm -rf build_${lib_type}
    mkdir build_${lib_type}
    pushd build_${lib_type}

    wrap cmake \
        -DCMAKE_BUILD_TYPE=RELEASE \
        -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
        -DCMAKE_CXX_STANDARD=17 \
        -DBUILD_SHARED_LIBS=${SHARED_LIBS} \
        -DSIMDUTF_TESTS=OFF \
        -DSIMDUTF_TOOLS=OFF \
        -DSIMDUTF_BENCHMARKS=OFF \
        -DSIMDUTF_ICONV=OFF \
        ..
    wrap make VERBOSE=1 -j${BUILD_THREADS:-4}
    wrap make install
    popd
  done

  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
