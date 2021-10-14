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

# Exit on non-true return value
set -e
# Exit on reference to uninitialized variable
set -u

set -o pipefail

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR

if needs_build_package ; then
  if [[ $PACKAGE_STRING =~ "-clangcompat" ]]; then
    # Get SOURCE_STRING from PACKAGE_STRING by eliminating "-clangcompat", then
    # download the dependency from S3
    SOURCE_STRING=${PACKAGE_STRING%-clangcompat}
    download_dependency $PACKAGE "${SOURCE_STRING}.tar.gz" $THIS_DIR

    # Patches are based on source version. Pass to setup_package_build function with
    # variable PATCH_DIR.
    SOURCE_VERSION=${PACKAGE_VERSION%-clangcompat}
    PATCH_DIR=${THIS_DIR}/${PACKAGE}-${SOURCE_VERSION}-patches

    setup_package_build $PACKAGE $PACKAGE_VERSION "${SOURCE_STRING}.tar.gz" \
        $SOURCE_STRING $PACKAGE_STRING
  else
    # Download the dependency from S3
    download_dependency $PACKAGE "${PACKAGE_STRING}.tar.gz" $THIS_DIR

    setup_package_build $PACKAGE $PACKAGE_VERSION
  fi
  add_gcc_to_ld_library_path
  wrap ./configure --with-pic --prefix=$LOCAL_INSTALL
  wrap make -j${BUILD_THREADS:-4} install
  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
