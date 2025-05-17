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
TCMALLOC_GITHUB_URL=${TCMALLOC_GITHUB_URL:-https://github.com/joemcdonnell/tcmalloc.git}
TCMALLOC_SOURCE_DIR=tcmalloc-$PACKAGE_VERSION
if [[ ! -d "${TCMALLOC_SOURCE_DIR}" ]]; then
  git clone $TCMALLOC_GITHUB_URL $TCMALLOC_SOURCE_DIR
  pushd $TCMALLOC_SOURCE_DIR
  git checkout $PACKAGE_VERSION -b "tcmalloc${PACKAGE_VERSION}"
  popd
fi

if ! needs_build_package; then
  exit
fi

setup_package_build $PACKAGE $PACKAGE_VERSION

# Find the location of abslConfig.cmake in abseil-cpp's directory
# This can't be hard-coded, because it varies across distributions (lib vs lib64).
ABSL_CONFIG_LOCATION=$(find $BUILD_DIR/abseil-cpp-${ABSEIL_CPP_VERSION} -name 'abslConfig.cmake')
[[ -f $ABSL_CONFIG_LOCATION ]]
ABSL_CONFIG_DIR=$(dirname ${ABSL_CONFIG_LOCATION})

rm -rf build_static
mkdir build_static
pushd build_static
wrap cmake -DCMAKE_BUILD_TYPE=RELEASE -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON -Dabsl_DIR=${ABSL_CONFIG_DIR} ..
wrap make VERBOSE=1 -j${BUILD_THREADS:-4}
wrap make install
popd

finalize_package_build $PACKAGE $PACKAGE_VERSION
