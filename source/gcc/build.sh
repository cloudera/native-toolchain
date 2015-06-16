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
  mkdir -p build
  cd build

  # Omitting the frame pointer is for debugability
  wrap ../gcc-$GCC_VERSION/configure --enable-frame-pointer --prefix=$LOCAL_INSTALL \
    --enable-cxx-flags='-fno-omit-frame-pointer' \
    --enable-languages=c,c++ --disable-multilib
  wrap make -j${BUILD_THREADS:-4}
  wrap make install
  footer $PACKAGE $PACKAGE_VERSION
fi
