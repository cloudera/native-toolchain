#!/usr/bin/env bash
# Copyright 2019 Cloudera Inc.
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

if needs_build_package; then
  cd $THIS_DIR
  NINJA_GITHUB_URL=https://github.com/ninja-build/ninja.git
  NINJA_SOURCE_DIR=ninja-$PACKAGE_VERSION
  if [[ ! -d "${NINJA_SOURCE_DIR}" ]]; then
    git clone $NINJA_GITHUB_URL $NINJA_SOURCE_DIR
    pushd $NINJA_SOURCE_DIR
    git checkout v${PACKAGE_VERSION} -b ninja${PACKAGE_VERSION}
    popd
  fi

  setup_package_build $PACKAGE $PACKAGE_VERSION

  rm -rf build
  mkdir build
  pushd build
  wrap cmake -DCMAKE_BUILD_TYPE=RELEASE -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
       -DBUILD_TESTING=OFF ..
  wrap make VERBOSE=1 -j${BUILD_THREADS:-4}
  wrap make install
  popd

  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
