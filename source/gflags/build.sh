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

  setup_package_build $PACKAGE $PACKAGE_VERSION

  # Recent glog releases (2.2.0+) now use CMake rather than autotools
  wrap cmake -DBUILD_STATIC_LIBS=ON -DBUILD_SHARED_LIBS=ON \
       -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL -DCMAKE_BUILD_TYPE=RELEASE \
       -DREGISTER_INSTALL_PREFIX=OFF
  # Previously, this would pass in CFLAGS to force PIC compilation. The default CFLAGS
  # force PIC compilation, so nothing special is needed.
  wrap make VERBOSE=1 -j${BUILD_THREADS:-4} install
  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
