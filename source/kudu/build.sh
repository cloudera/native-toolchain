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

# In addition to the usual build env vars, BOOST_VERSION must be set.
#
# PACKAGE_VERSION can be a tag, branch, or hash.

if [[ "$DEBUG" == 1 ]]; then
  set -x
fi

set -euo pipefail

THIS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Returns success if Kudu can be built on this platform.
function is_supported_platform {
  set +u
  if [[ -z "$OS_NAME" || -z "$OS_VERSION" || -z "$ARCH_NAME" ]]; then
    echo OS_NAME, OS_VERSION and ARCH_NAME must be set before calling this script.
    return 1
  fi
  if [[ "$ARCH_NAME" == "ppc64le" ]]; then
    return 1
  fi
  set -u
  case "$OS_NAME" in
    # RHEL 5 can't build the Kudu toolchain llvm and likely more (very early failure).
    # Debian 6 and Sles 11 can't build the Kudu toolchain libpmem.
    rhel) [[ "$OS_VERSION" -ge 6 ]];;
    debian) [[ "$OS_VERSION" -ge 7 ]];;
    suse) [[ "$OS_VERSION" -ge 12 ]];;

    # For any other OS just assume it'll work.
    *) true;;
  esac
}

function build {
  set +u
  if [[ -z "$BOOST_VERSION" ]]; then
    echo BOOST_VERSION must be set before calling this script. The value should \
        correspond to a version available in the toolchain.
    exit 1
  fi
  set -u

  export BOOST_ROOT="$BUILD_DIR/boost-$BOOST_VERSION"
  if [[ ! -d "$BOOST_ROOT" ]]; then
    echo BOOST_ROOT has an implied value of "'$BOOST_ROOT'" but that directory does not \
        exist.
    exit 1
  fi

  source $SOURCE_DIR/functions.sh
  prepare $THIS_DIR

  cd $THIS_DIR
  # Allow overriding of the github URL from the environment - e.g. if we want to build
  # a hash from a forked repo. Fetch over SSH because github.com does not allow TLS < V1.2
  # connections and therefore https won't work for some older distributions.
  KUDU_GITHUB_URL=${KUDU_GITHUB_URL:-git@github.com:apache/kudu.git}
  KUDU_SOURCE_DIR=kudu-$PACKAGE_VERSION
  if [[ ! -d "$KUDU_SOURCE_DIR" ]]; then
    git clone $KUDU_GITHUB_URL $KUDU_SOURCE_DIR
    pushd $KUDU_SOURCE_DIR
    git checkout $PACKAGE_VERSION
    popd
  fi

  if ! needs_build_package; then
    return
  fi

  setup_package_build $PACKAGE $PACKAGE_VERSION

  # Kudu's dependencies are not in the toolchain. They could be added later.
  cd thirdparty
  # For some reason python 2.7 from Kudu's thirdparty doesn't build on CentOS 6. It's
  # not really needed since the toolchain provides python 2.7. To skip the thirdparty
  # build, "python2.7" needs to be in the PATH.
  OLD_PATH="$PATH"
  PATH="$BUILD_DIR/python-2.7.15/bin:$OLD_PATH"
  wrap ./build-if-necessary.sh
  cd ..

  # Update the PATH to include Kudu's toolchain binaries (after our toolchain's Python).
  KUDU_TP_PATH="`pwd`/thirdparty/installed/common/bin"
  PATH="$BUILD_DIR/python-2.7.15/bin:$KUDU_TP_PATH:$OLD_PATH"

  # Now Kudu can be built.
  RELEASE_INSTALL_DIR="$LOCAL_INSTALL/release"
  mkdir -p release_build_dir
  pushd release_build_dir
  wrap cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DNO_TESTS=1 \
      -DCMAKE_INSTALL_PREFIX="$RELEASE_INSTALL_DIR" ..
  wrap make -j$BUILD_THREADS
  install_kudu "$RELEASE_INSTALL_DIR"
  popd

  # Build the debug version too.
  DEBUG_INSTALL_DIR="$LOCAL_INSTALL/debug"
  mkdir -p debug_build_dir
  pushd debug_build_dir
  wrap cmake \
      -DCMAKE_BUILD_TYPE=Debug \
      -DKUDU_LINK=static \
      -DNO_TESTS=1 \
      -DCMAKE_INSTALL_PREFIX="$DEBUG_INSTALL_DIR" ..
  wrap make -j$BUILD_THREADS
  install_kudu "$DEBUG_INSTALL_DIR"
  popd

  cd $THIS_DIR

  finalize_package_build $PACKAGE $PACKAGE_VERSION
}

# This should be called from the Kudu build dir.
function install_kudu {
  INSTALL_DIR=$1

  # This actually only installs the client.
  wrap make install

  # Install the binaries, but only the needed stuff. Ignore the test utilities. The list
  # of files below should match the files provided by a parcel.
  rm -rf "$INSTALL_DIR/bin"
  mkdir -p "$INSTALL_DIR/bin"
  pushd bin
  for F in kudu-* ; do
    cp $F "$INSTALL_DIR/bin"
  done
  popd

  # Install the web server resources.
  rm -rf "$INSTALL_DIR/lib/kudu/www"
  mkdir -p "$INSTALL_DIR/lib/kudu"
  cp -r ../www "$INSTALL_DIR/lib/kudu"
}

# Run build or a requested function.
${1-build}
