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

  # The extracted package dir has "release" in the name.
  EXTRACTED_DIR="${PACKAGE}-release-${PACKAGE_VERSION}"
  setup_package_build $PACKAGE $PACKAGE_VERSION "${PACKAGE_STRING}.tar.gz" \
      "$EXTRACTED_DIR"

  pushd ..
  mkdir -p build-googletest-$GOOGLETEST_VERSION
  pushd build-googletest-$GOOGLETEST_VERSION
  wrap cmake -DCMAKE_CXX_FLAGS="${CXXFLAGS}" -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL "../${EXTRACTED_DIR}"
  wrap make -j${BUILD_THREADS:-4}
  wrap make install

  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
