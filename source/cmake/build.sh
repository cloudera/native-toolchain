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

# Turn off debug info for CMake by adding -g0, as it is just a build utility.
CXXFLAGS="${CXXFLAGS} -g0"
CFLAGS="${CFLAGS} -g0"

if needs_build_package ; then
  # Download the dependency from S3
  download_dependency $PACKAGE "${PACKAGE_STRING}.tar.gz" $THIS_DIR
  setup_package_build $PACKAGE $PACKAGE_VERSION
  add_gcc_to_ld_library_path

  # Set KWSYS_PROCESS_USE_SELECT to workaround IMPALA-3191.
  #   NOTE: the CMakeLists.txt in CMake seems to have a bug in which
  #   we have to define two very similar-looking options to get the
  #   desired behavior.
  wrap ./bootstrap --prefix=${LOCAL_INSTALL} --parallel=${BUILD_THREADS} \
    -- -DKWSYS_PROCESS_USE_SELECT=0 -DKWSYSPE_USE_SELECT=0
  wrap make VERBOSE=1 -j${BUILD_THREADS}
  wrap make install

  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
