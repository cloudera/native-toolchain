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
  # a hash from a forked repo.
  KUDU_GITHUB_URL=${KUDU_GITHUB_URL:-https://github.com/apache/kudu.git}
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
  add_gcc_to_ld_library_path

  # Modify the version.txt file to use a commit hash rather than a SNAPSHOT version
  # Verify version.txt exists, then overwrite it.
  [[ -f version.txt ]]
  echo $PACKAGE_VERSION > version.txt

  # Workaround for IMPALA-13309: A Maven repository shut down and maven central only has
  # gradle-scalafmt at a different artifact path. Patch build.gradle to use the working
  # path. This won't match anything for newer Kudu versions that don't have this issue.
  # NOTE: Remove this when we move to a newer Kudu.
  sed -i 's#compile "cz.alenkacz:gradle-scalafmt#compile "gradle.plugin.cz.alenkacz:gradle-scalafmt#' \
    java/buildSrc/build.gradle

  export GRADLE_USER_HOME="$(pwd)"

  # Kudu's dependencies are not in the toolchain. They could be added later.
  cd thirdparty

  # Kudu's thirdparty compilation of curl depends on being able to find krb5-config
  # on the path. On SLES12, this can be in /usr/lib/mit/bin, so include that directory
  # if it exists.
  if [[ -d /usr/lib/mit/bin ]]; then
    PATH="$PATH:/usr/lib/mit/bin"
  fi
  LOAD_AVERAGE_ARGS="--load-average=${BUILD_THREADS}"
  # Kudu uses ninja if ninja is available. Ninja doesn't support --load-average,
  # so don't use --load-average if ninja is installed. The build docker images
  # don't install ninja, so this is uncommon.
  if command -v ninja-build || command -v ninja ; then
    echo "Ninja is installed, disabling --load-average"
    LOAD_AVERAGE_ARGS=""
  fi
  # When building Kudu's toolchain, debug symbols are not particularly useful
  # for Impala development and they add substantial size to the Kudu binary.
  # For example, compiling LLVM even with -g1 can add hundreds of MBs to the
  # Kudu binary sizes. This turns off debug symbols for Kudu's toolchain.
  STORE_CFLAGS=${CFLAGS}
  STORE_CXXFLAGS=${CXXFLAGS}
  CFLAGS="${CFLAGS} -g0"
  CXXFLAGS="${CXXFLAGS} -g0"
  EXTRA_MAKEFLAGS="${LOAD_AVERAGE_ARGS}" wrap ./build-if-necessary.sh
  CFLAGS=$STORE_CFLAGS
  CXXFLAGS=$STORE_CXXFLAGS
  cd ..

  # Update the PATH to include Kudu's toolchain binaries.
  KUDU_TP_PATH="`pwd`/thirdparty/installed/common/bin"
  PATH="$KUDU_TP_PATH:$PATH"

  # Now Kudu can be built.
  RELEASE_INSTALL_DIR="$LOCAL_INSTALL/release"
  mkdir -p release_build_dir
  pushd release_build_dir
  wrap cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DNO_TESTS=1 \
      -DCMAKE_INSTALL_PREFIX="$RELEASE_INSTALL_DIR" ..
  wrap make VERBOSE=1 -j$BUILD_THREADS --load-average=${BUILD_THREADS}
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
  wrap make VERBOSE=1 -j$BUILD_THREADS --load-average=${BUILD_THREADS}
  install_kudu "$DEBUG_INSTALL_DIR"
  popd

  # Build Java artifacts
  local JAVA_INSTALL_DIR="$LOCAL_INSTALL/java"
  mkdir -p "$JAVA_INSTALL_DIR"
  pushd java
  wrap ./gradlew :kudu-hive:assemble :kudu-client:assemble
  # Copy kudu-hive jars to JAVA_INSTALL_DIR.
  local F
  for F in kudu-hive/build/libs/kudu-hive-*.jar; do
    cp "$F" "$JAVA_INSTALL_DIR"
  done
  # Install kudu-client artifacts to the Local Maven Repository:
  wrap ./gradlew -Dmaven.repo.local="${JAVA_INSTALL_DIR}/repository" :kudu-client:publishToMavenLocal
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
    # Create symlinks to reduce package size, see: IMPALA-11454
    if [[ "$F" == "kudu-master" || "$F" == "kudu-tserver" ]]; then
        ln -s "../sbin/$F" "$INSTALL_DIR/bin/$F"
    else
        cp "$F" "$INSTALL_DIR/bin"
    fi
  done
  popd

  # Install the web server resources.
  rm -rf "$INSTALL_DIR/lib/kudu/www"
  mkdir -p "$INSTALL_DIR/lib/kudu"
  cp -r ../www "$INSTALL_DIR/lib/kudu"
}

# Run build or a requested function.
${1-build}
