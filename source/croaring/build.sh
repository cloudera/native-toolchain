#!/usr/bin/env bash
# Copyright 2026 Cloudera Inc.
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
  # Upstream keeps the project's mixed-case spelling, while the toolchain package
  # name is lowercased by prepare(). The tarball extracts to CRoaring-VERSION.
  TARBALL_BASE_NAME="CRoaring-${PACKAGE_VERSION}"

  # Download the dependency from S3
  download_dependency CRoaring "${TARBALL_BASE_NAME}.tar.gz" $THIS_DIR

  # Rename the directory from CRoaring-VERSION to croaring-VERSION
  setup_package_build $PACKAGE $PACKAGE_VERSION "${TARBALL_BASE_NAME}.tar.gz" \
      "$TARBALL_BASE_NAME" $PACKAGE_STRING

  # CRoaring's CMake builds either a shared or a static library, but not both.
  # Build each separately so dynamically-linked Impala builds are supported too.
  # Static is built last so the CMake package config, which both builds write
  # to the same files, describes the static library.
  for lib_type in shared static ; do
    if [[ "$lib_type" == "shared" ]]; then
      SHARED_LIBS=ON
    else
      SHARED_LIBS=OFF
    fi

    rm -rf build_${lib_type}
    mkdir build_${lib_type}
    pushd build_${lib_type}

    # ROARING_USE_CPM=OFF keeps the configure step from downloading CPM.cmake
    # from GitHub, which it does even when the tests that need it are disabled.
    # CMAKE_INSTALL_LIBDIR is pinned because GNUInstallDirs otherwise picks
    # lib64 on non-Debian platforms.
    wrap cmake \
        -DCMAKE_BUILD_TYPE=RELEASE \
        -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DBUILD_SHARED_LIBS=${SHARED_LIBS} \
        -DENABLE_ROARING_TESTS=OFF \
        -DROARING_USE_CPM=OFF \
        ..
    wrap make VERBOSE=1 -j${BUILD_THREADS:-4}

    # Both variants export the same CMake package files, and CMake skips
    # installing a file whose timestamp is not newer than the installed copy
    # (timestamps are compared at one second granularity, and with a warm ccache
    # both variants are built within the same second). Without this the static
    # install can leave the shared build's roaring-targets.cmake in place, which
    # then declares a SHARED imported target pointing at libroaring.a.
    rm -rf $LOCAL_INSTALL/lib/cmake/roaring
    wrap make install
    popd
  done

  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
