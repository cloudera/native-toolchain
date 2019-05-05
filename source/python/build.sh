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
  ARCHIVE_FILE="${PACKAGE_STRING}.tar.xz"
  download_dependency $PACKAGE $ARCHIVE_FILE $THIS_DIR

  setup_package_build $PACKAGE $PACKAGE_VERSION $ARCHIVE_FILE "Python-${PYTHON_VERSION}"

  # Python bakes the name of the C and C++ compilers into the package to be used for
  # building native packages. We want the defaults to be just the name of the compiler,
  # e.g. "gcc" and "g++" without any additional path, particularly not any temporary
  # directories, because consumers of the toolchain will likely install the compilers in
  # a different directory from the one used during our toolchain build.
  export PATH="$(dirname ${CC}):$(dirname ${CXX}):$PATH"
  CC=$(basename ${CC})
  CXX=$(basename ${CXX})

  LDFLAGS= wrap ./configure --prefix=$LOCAL_INSTALL
  wrap make -j${BUILD_THREADS:-4}
  wrap make install
  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
