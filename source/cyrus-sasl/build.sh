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

  WITH_FRAMEWORKS=
  if [[ "$OSTYPE" == "darwin"* ]]; then
    WITH_FRAMEWORKS=--disable-macos-framework
  fi

  CONFIGURE_FLAGS=
  # If libdb5 is installed, it would be used by default and would lead to a failure.
  # If libdb4 appears to be installed, use that instead. The location below was found
  # on a CentOS 7 machine.
  if [[ -e /usr/include/libdb4 && -e /usr/lib64/libdb4 ]]; then
    CONFIGURE_FLAGS+=" --with-bdb-incdir=/usr/include/libdb4"
    CONFIGURE_FLAGS+=" --with-bdb-libdir=/usr/lib64/libdb4"
  fi

  # Disable everything except those protocols needed -- currently just Kerberos.
  # Sasl does not have a --with-pic configuration.
  CFLAGS="$CFLAGS -fPIC -DPIC" CXXFLAGS="$CXXFLAGS -fPIC -DPIC" wrap ./configure \
    --disable-sql --disable-otp --disable-ldap --disable-digest --with-saslauthd=no \
    $CONFIGURE_FLAGS \
    --prefix=$LOCAL_INSTALL --enable-static --enable-staticdlopen $WITH_FRAMEWORKS
  # the first time you do a make it fails, build again.
  wrap make || /bin/true
  wrap make -j${BUILD_THREADS:-4}
  wrap make install

  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
