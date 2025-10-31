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

cd $THIS_DIR
BREAKPAD_GITHUB_URL=https://github.com/google/breakpad.git
BREAKPAD_SOURCE_DIR=breakpad-$PACKAGE_VERSION
LSS_REPO=https://chromium.googlesource.com/linux-syscall-support

if [[ ! -d "${BREAKPAD_SOURCE_DIR}" ]]; then
  git clone $BREAKPAD_GITHUB_URL $BREAKPAD_SOURCE_DIR
  pushd $BREAKPAD_SOURCE_DIR
  git checkout $PACKAGE_VERSION -b $PACKAGE_VERSION

  # Detect LSS_VERSION. The DEPS file follows Python syntax, so we can append a python
  # print statement to print out the LSS commit hash.
  # There are other dependencies, but they are not needed for what we are building.
  cp DEPS print_lss_version.py
  echo 'print(deps["src/src/third_party/lss"].split("@")[1])' >> print_lss_version.py
  LSS_VERSION="$(python3 print_lss_version.py)"
  rm print_lss_version.py

  # Checkout LSS under src/third_party
  git clone $LSS_REPO src/third_party/lss
  pushd src/third_party/lss
  git checkout $LSS_VERSION -b $LSS_VERSION
  popd
  popd
fi

if needs_build_package ; then
  setup_extracted_package_build $PACKAGE $PACKAGE_VERSION $BREAKPAD_SOURCE_DIR

  wrap ./configure --prefix=$LOCAL_INSTALL
  wrap make VERBOSE=1 -j${BUILD_THREADS:-4}
  wrap make install
  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
