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

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR

if needs_build_package ; then
  # Download the dependency from S3
  download_dependency $PACKAGE "${PACKAGE_STRING}.tar.gz" $THIS_DIR

  setup_package_build $PACKAGE $PACKAGE_VERSION

  ARCH_FLAGS=
  if [[ "$OSTYPE" == "darwin"* ]]; then
    ARCH_FLAGS="darwin64-x86_64-cc enable-ec_nistp_64_gcc_128"
  else
    ARCH_FLAGS="linux-x86_64 enable-ec_nistp_64_gcc_128"
  fi

  CFLAGS="$CFLAGS -fPIC -DPIC" \
    CXXFLAGS="$CXXFLAGS -fPIC -DPIC" \
    wrap perl ./Configure no-ssl2 no-ssl3 shared zlib \
      --prefix=$LOCAL_INSTALL $ARCH_FLAGS

  # For some reason, the first build seems to fail sometimes
  wrap make all
  wrap make install

  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
