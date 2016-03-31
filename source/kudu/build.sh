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
# KUDU_VERSION can be a tag, branch, or hash. If a hash is used, it should be the full
# hash. A partial hash will lead to an error. After downloading a .zip of the source,
# the extracted dir name won't match what the other scripts/functions expect.

if [[ "$DEBUG" == 1 ]]; then
  set -x
fi

set -euo pipefail

set +u
if [[ -z "$KUDU_VERSION" ]]; then
  echo KUDU_VERSION must be set before calling this script. The value should \
      correspond to a git hash or tag available at \
      https://github.com/apache/incubator-kudu.
  exit 1
fi
set -u

THIS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Returns success if Kudu can be built on this platform.
function is_supported_platform {
  set +u
  if [[ -z "$OS_NAME" || -z "$OS_VERSION" ]]; then
    echo OS_NAME and OS_VERSION must be set before calling this script.
    return 1
  fi
  set -u
  case "$OS_NAME" in
    rhel) [[ "$OS_VERSION" -ge 6 ]];;
    ubuntu) [[ "$OS_VERSION" -ge 14 ]];;

    # SUSE and Debian are known to fail.
    suse | debian) false;;

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
  download_url https://github.com/apache/incubator-kudu/archive/$KUDU_VERSION.tar.gz \
      kudu-$KUDU_VERSION.tar.gz

  if ! needs_build_package; then
    return
  fi

  header $PACKAGE $PACKAGE_VERSION kudu-$KUDU_VERSION.tar.gz \
      incubator-kudu-$KUDU_VERSION incubator-kudu-$KUDU_VERSION "tar xzf"

  # Kudu's dependencies are not in the toolchain. They could be added later.
  cd thirdparty
  # For some reason python 2.7 from Kudu's thirdparty doesn't build on CentOS 6. It's
  # not really needed since the toolchain provides python 2.7. To skip the thirdparty
  # build, "python2.7" needs to be in the PATH.
  OLD_PATH="$PATH"
  PATH="$BUILD_DIR/python-2.7.10/bin:$PATH"
  wrap ./build-if-necessary.sh
  PATH="$OLD_PATH"
  cd ..

  # The line below configures clang to find gcc from the toolchain. Without this the
  # build will still work on some systems but there will be strange crashes at runtime.
  # On other systems, such as default RHEL6, the build will fail because c++11 isn't
  # supported on the system gcc.
  sed -i -r "s:^(set\(IR_FLAGS):\1\n  --gcc-toolchain=$(dirname $(which $CXX))/..:" \
      src/kudu/codegen/CMakeLists.txt

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

  footer $PACKAGE $PACKAGE_VERSION
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
  for F in kudu-* cfile-dump log-dump; do
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
