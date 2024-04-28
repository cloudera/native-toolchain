#!/usr/bin/env bash
# Copyright 2017 Cloudera Inc.
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
  add_gcc_to_ld_library_path

  GCC_MAJOR_VERSION=$(echo $GCC_VERSION | cut -d . -f1)
  if (( GCC_MAJOR_VERSION >= 7 )); then
    # Prevent implicit fallthrough warning in GCC7+ from failing build.
    CXXFLAGS+=" -Wno-error=implicit-fallthrough"
  fi
  # flatbuffers build occasionally fails when using -j${BUILD_THREADS} with an error similar to:
  # /mnt/source/flatbuffers/flatbuffers-1.6.0/samples/sample_binary.cpp:19:17: error: 'MyGame' has not been declared
  # /mnt/source/flatbuffers/flatbuffers-1.6.0/samples/sample_binary.cpp:19:25: error: 'Sample' is not a namespace-name
  # ...
  # Disabling build tests gets rid of this flakiness and makes the compilation faster.
  # Flatbuffers 1.9 has an issue where it will not install flatc unless CMAKE_BUILD_TYPE=Release,
  # so this adds that flag (which is useful anyway).
  wrap cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=${LOCAL_INSTALL} \
      -DCMAKE_CXX_FLAGS="$CXXFLAGS" -DFLATBUFFERS_BUILD_TESTS="OFF" \
      -DCMAKE_BUILD_TYPE=Release
  wrap make VERBOSE=1 -j${BUILD_THREADS:-4} install
  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
