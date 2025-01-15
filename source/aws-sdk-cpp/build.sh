#!/usr/bin/env bash
# Copyright 2025 Cloudera Inc.
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
  download_dependency $PACKAGE "${PACKAGE_STRING}.tar.gz" $THIS_DIR
  setup_package_build $PACKAGE $PACKAGE_VERSION
  # This is required for downloading some dependencies.
  ORIGINAL_PATH=$PATH
  CURL_PATH=${BUILD_DIR}/curl-${CURL_VERSION}/bin
  export PATH="$CURL_PATH:$PATH"
  wrap ./prefetch_crt_dependency.sh
  export PATH=$ORIGINAL_PATH
  # Build only the required bedrock components.
  wrap cmake -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL -DCMAKE_BUILD_TYPE=RELEASE \
    -DBUILD_ONLY="bedrock-runtime" -DENABLE_TESTING="OFF" -DUSE_OPENSSL="ON" \
    -DBUILD_SHARED_LIBS="OFF" -DCPP_STANDARD="17" \
    -DCURL_LIBRARY=${BUILD_DIR}/curl-${CURL_VERSION}/lib/libcurl.so \
    -DCURL_INCLUDE_DIR=${BUILD_DIR}/curl-${CURL_VERSION}/include \
    -DZLIB_ROOT=${BUILD_DIR}/zlib-${ZLIB_VERSION}
  wrap make VERBOSE=1 -j${BUILD_THREADS:-4} install
  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
