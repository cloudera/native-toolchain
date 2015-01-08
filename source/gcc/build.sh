#!/bin/bash
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

set -eu

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR


if [ ! -f $SOURCE_DIR/check/$PACKAGE_STRING ]; then
  header $PACKAGE $PACKAGE_VERSION

  ./contrib/download_prerequisites

  cd ..
  mkdir build
  cd build

  ../gcc-$GCC_VERSION/configure --prefix=$LOCAL_INSTALL --enable-languages=c,c++ --disable-multilib >> $BUILD_LOG 2>&1
  make -j${IMPALA_BUILD_THREADS:-4}  >> $BUILD_LOG 2>&1
  make install >> $BUILD_LOG 2>&1
  footer $PACKAGE $PACKAGE_VERSION
fi
