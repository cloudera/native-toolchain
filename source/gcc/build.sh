#!/bin/bash
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

set -eu

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR

# Download the dependency from S3
download_dependency $LPACKAGE "${LPACKAGE_VERSION}.tar.gz" $THIS_DIR

if [ ! -f $SOURCE_DIR/check/$PACKAGE_STRING ]; then
  header $PACKAGE $PACKAGE_VERSION

  ./contrib/download_prerequisites


  if [[ "$OSTYPE" == "darwin"* ]]; then
    # Patch GMP
    pushd gmp-4.3.2
    patch -p1 < ../../manual_patches_gcc-4.9.2/gmp.patch
    popd
  fi

  cd ..
  mkdir -p build
  cd build

  wrap ../gcc-$GCC_VERSION/configure --prefix=$LOCAL_INSTALL \
    --enable-languages=c,c++ --disable-multilib \
    --with-build-config=bootstrap-debug
  wrap make -j${BUILD_THREADS:-4}
  wrap make install
  footer $PACKAGE $PACKAGE_VERSION
fi
