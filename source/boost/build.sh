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
  add_gcc_to_ld_library_path

  if [[ ! "$OSTYPE" == "darwin"* && $SYSTEM_GCC -eq 0 ]]; then
    echo "using gcc : $GCC_VERSION : $BUILD_DIR/gcc-$GCC_VERSION/bin/g++ ;" > tools/build/src/user-config.jam
    TOOLSET=--toolset=gcc-$GCC_VERSION
  else
    TOOLSET=
  fi
  CXXFLAGS+=" -Wno-deprecated-declarations"
  # Update compilers to use our toolchain
  wrap ./bootstrap.sh --without-libraries=python --prefix=$LOCAL_INSTALL cxxflags="$CXXFLAGS"
  wrap ./b2 -s"NO_BZIP2=1" $TOOLSET cxxflags="$CXXFLAGS" linkflags="$CXXFLAGS" --prefix=$LOCAL_INSTALL -j"${BUILD_THREADS:-4}" install
  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
