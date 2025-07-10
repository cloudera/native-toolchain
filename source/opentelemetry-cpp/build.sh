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

# Exit on non-true return value, reference to uninitialized variable
set -euo pipefail

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR

if needs_build_package ; then
  # Download the dependency from S3
  download_dependency $PACKAGE "${PACKAGE_STRING}.tar.gz" $THIS_DIR

  setup_package_build $PACKAGE $PACKAGE_VERSION

  wrap cmake \
      -DBUILD_SHARED_LIBS=OFF \
      -DBUILD_TESTING=OFF \
      -DCMAKE_BUILD_TYPE=RELEASE \
      -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
      -DWITH_BENCHMARK=OFF \
      -DWITH_EXAMPLES=OFF \
      -DWITH_OTLP_GRPC=OFF \
      -DCURL_ROOT=${BUILD_DIR}/curl-${CURL_VERSION} \
      -DProtobuf_ROOT=${BUILD_DIR}/protobuf-${PROTOBUF_VERSION} \
      -DZLIB_ROOT=${BUILD_DIR}/zlib-${ZLIB_VERSION} \
      -DWITH_OTLP_HTTP=ON \
      -DWITH_OTLP_HTTP_COMPRESSION=ON \
      -DWITH_THREAD_INSTRUMENTATION_PREVIEW=ON \
      -DWITH_OTLP_FILE=ON \
      -DWITH_STL=CXX17 \
      -DCMAKE_CXX_STANDARD=17
  wrap make VERBOSE=1 -j${BUILD_THREADS:-4}
  wrap make install

  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
