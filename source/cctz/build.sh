#!/usr/bin/env bash
# Copyright 2018 Cloudera Inc.
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
  download_dependency $PACKAGE "cctz-${PACKAGE_VERSION}.tar.gz" $THIS_DIR
  setup_package_build $PACKAGE $PACKAGE_VERSION

  # versioned shared library name, soname
  SHARED_LIB_VER_NAME="lib${PACKAGE}.so.${PACKAGE_VERSION}"
  SHARED_LIB_SONAME="lib${PACKAGE}.so.${PACKAGE_VERSION%%.*}"

  # build in a separate subdirectory for clarity
  mkdir -p build
  wrap make VERBOSE=1 -C build -f ../Makefile SRC=../ -j${BUILD_THREADS:-4} \
      PREFIX="$LOCAL_INSTALL" \
      SHARED_LDFLAGS="-shared -Wl,-soname,$SHARED_LIB_SONAME" \
      CCTZ_SHARED_LIB="$SHARED_LIB_VER_NAME" \
      install install_shared_lib

  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
