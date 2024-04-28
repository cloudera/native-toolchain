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

cd $THIS_DIR
ABSEIL_CPP_GITHUB_URL=https://github.com/abseil/abseil-cpp.git
ABSEIL_CPP_SOURCE_DIR=abseil-cpp-$PACKAGE_VERSION
if [[ ! -d "${ABSEIL_CPP_SOURCE_DIR}" ]]; then
  git clone $ABSEIL_CPP_GITHUB_URL $ABSEIL_CPP_SOURCE_DIR
  pushd $ABSEIL_CPP_SOURCE_DIR
  git checkout $PACKAGE_VERSION
  popd
fi

if ! needs_build_package; then
  exit
fi

setup_package_build $PACKAGE $PACKAGE_VERSION

rm -rf build_static
mkdir build_static
pushd build_static
wrap cmake -DCMAKE_BUILD_TYPE=RELEASE -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
     -DABSL_ENABLE_INSTALL=ON -DABSL_BUILD_TESTING=OFF ..
wrap make VERBOSE=1 -j${BUILD_THREADS:-4}
wrap make install
popd

rm -rf build_shared
mkdir build_shared
pushd build_shared
wrap cmake -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=RELEASE \
     -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
     -DABSL_ENABLE_INSTALL=ON -DABSL_BUILD_TESTING=OFF ..
wrap make VERBOSE=1 -j${BUILD_THREADS:-4}
wrap make install
popd

finalize_package_build $PACKAGE $PACKAGE_VERSION
