#!/usr/bin/env bash
# Copyright 2012 Cloudera Inc.
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

# cleans and rebuilds thirdparty/. The Impala build environment must be set up
# by bin/impala-config.sh before running this script.

# Exit on non-true return value
set -e
# Exit on reference to uninitialized variable
set -u

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR

if [ ! -f $SOURCE_DIR/check/$PACKAGE_STRING ]; then
  header $PACKAGE $PACKAGE_VERSION

  echo "using gcc : 4.9.2 : $BUILD_DIR/gcc-$GCC_VERSION/bin/g++ ;" > tools/build/src/user-config.jam
  # Update compilers to use our toolchain
  ./bootstrap.sh --prefix=$LOCAL_INSTALL >> $BUILD_LOG 2>&1
  ./b2 --toolset=gcc-4.9.2 cxxflags="$CXXFLAGS" linkflags="$CXXFLAGS" --prefix=$LOCAL_INSTALL -j4 install >> $BUILD_LOG 2>&1

  footer $PACKAGE $PACKAGE_VERSION
fi
