#!/usr/bin/env bash
# Copyright 2016 Cloudera Inc.
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

set -euo pipefail

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR
cd $THIS_DIR

PARCEL_URL="http://archive.cloudera.com/beta/kudu/parcels/"

case $OS_NAME-$OS_VERSION in
  ubuntu-14)
    PARCEL_OS_LABEL=trusty
    GEN_STUB_CLIENT=false;;
  rhel-7)
    PARCEL_OS_LABEL=el7
    GEN_STUB_CLIENT=false;;
  rhel-6)
    PARCEL_OS_LABEL=el6
    GEN_STUB_CLIENT=false;;
  *)
    # A real parcel is needed to generate the client stub. The el6 parcel should work
    # as well as any other.
    PARCEL_OS_LABEL=el6
    GEN_STUB_CLIENT=true;;
esac

case $PACKAGE_VERSION in
  0.7.0)
    PARCEL_BASE_NAME="KUDU-0.7.0-1.kudu0.7.0.p0.27"
    PARCEL_URL+="0.7.0/$PARCEL_BASE_NAME-$PARCEL_OS_LABEL.parcel";;
  *)
    echo "Unsupported version: $PACKAGE_VERSION"
    exit 1;;
esac

download_url "$PARCEL_URL"

if needs_build_package; then
  FILE_NAME=$(basename $PARCEL_URL)
  DIR_NAME=$PACKAGE-$PACKAGE_VERSION
  rm -rf $DIR_NAME
  header $PACKAGE $PACKAGE_VERSION $FILE_NAME $PARCEL_BASE_NAME $DIR_NAME
  if $GEN_STUB_CLIENT; then
    # The name of the file to be generated.
    STUB_CLIENT=stub_client.so
    STUB_CLIENT_SRC=stub_client.cpp

    # Find a non-debug client lib.
    REAL_CLIENT=$(find . -name 'libkudu_client*.so*' -not -path '*debug*' | head -n 1)

    # Set the path to pickup "nm" and "python" from the toolchain. Older OSs such as
    # RHEL 5 may not have a new enough version to properly list the symbols.
    OLD_PATH="$PATH"
    PATH="$BUILD_DIR/bin:$PATH"
    python ../gen-stub-so.py $REAL_CLIENT > $STUB_CLIENT_SRC
    SO_NAME=$(objdump -p $REAL_CLIENT | grep SONAME | awk '{ print $2 }')

    # Restore the old path to use the system linker.
    PATH="$OLD_PATH"
    # The soname is necessary on older Debian systems.
    $CXX $STUB_CLIENT_SRC -shared -fPIC -Wl,-soname,$SO_NAME -o $STUB_CLIENT

    # Replace the libs with the stub.
    for F in $(find . -name 'libkudu_client*.so*' -type f); do
      rm -f $F
      cp $STUB_CLIENT $F
    done

    rm -f $STUB_CLIENT_SRC $STUB_CLIENT
  fi
  rm -rf $LOCAL_INSTALL
  cp -r $PWD $LOCAL_INSTALL
  footer $PACKAGE $PACKAGE_VERSION
fi
