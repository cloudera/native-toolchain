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

  # --disable-silent-rules enables verbose output including the compilation command
  # This disables some functionalities that we don't need (FTP, Gopher, etc), which
  # reduces surface area for vulnerabilities.
  wrap ./configure --with-pic --with-openssl --disable-silent-rules \
       --with-gssapi \
       --prefix=$LOCAL_INSTALL \
       --disable-dict \
       --disable-file \
       --disable-ftp \
       --disable-gopher \
       --disable-imap \
       --disable-ldap \
       --disable-ldaps \
       --disable-libcurl-option \
       --disable-mqtt \
       --disable-pop3 \
       --disable-rtsp \
       --disable-smb \
       --disable-smtp \
       --disable-telnet \
       --disable-tftp \
       --without-brotli \
       --without-libidn2 \
       --without-libpsl \
       --without-librtmp \
       --without-libssh2 \
       --without-nghttp2 \
       --without-zstd
  wrap make -j${BUILD_THREADS:-4} install

  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
