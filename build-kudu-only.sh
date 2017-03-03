#!/usr/bin/env bash
# Copyright 2017 Cloudera Inc.
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

# Builds Kudu using an existing toolchain.
# Uses the following environment variables:
# BUILD_LABEL: (Required) The build label for the platform to build. This should
#              match the label in the published toolchain packages.
#              E.g. 'ubuntu-14-04'
# TOOLCHAIN_BUILD_ID: The toolchain build ID to be used for building Kudu. If not set,
#                     this defaults to the latest build ID in Impala/master.
# KUDU_VERSION: The git hash/tag of Kudu to build. If not set, this defaults to the
#               latest commit on master.

# Exit on non-true return value
set -e
# Exit on reference to uninitialized variable
set -u
set -o pipefail

SOURCE_DIR="$( cd "$( dirname "$0" )" && pwd )"

# Temp dir for extracting existing toolchain packages.
TMP_DIR=$(mktemp -d)

# Directory for downloading existing toolchain packages.
DL_DIR=$TMP_DIR/dl

# Dependencies Kudu has on toolchain packages.
KUDU_DEPENDENCIES="gcc python cmake binutils boost libtool automake autoconf"

# Downloads a pre-built dependency from an existing toolchain build. Argument is
# the package name.
function download_toolchain_dependency() {
  local DL_PKG_NAME=$1
  local S3_BASE_PREFIX=s3://native-toolchain/build

  echo "Downloading $1 ..."
  aws s3 cp $S3_BASE_PREFIX/$TOOLCHAIN_BUILD_ID/ $DL_DIR --recursive \
    --exclude "*" --include "*/${DL_PKG_NAME}*${BUILD_LABEL}*"
}

function get_impala_master_toolchain_id() {
  # URL to access raw Impala repo files
  local RAW_GITHUB_URL=https://raw.githubusercontent.com/apache/incubator-impala
  local IMPALA_REPO_BRANCH=master

  # URL to download the impala-config.sh
  local IMPALA_CONFIG_URL=${RAW_GITHUB_URL}/${IMPALA_REPO_BRANCH}/bin/impala-config.sh

  curl -s $IMPALA_CONFIG_URL | grep TOOLCHAIN_BUILD_ID | sed 's/.*=//'
}

function get_kudu_master_hash() {
  local KUDU_GIT_REPO=http://git.apache.org/kudu.git
  git ls-remote $KUDU_GIT_REPO master | cut -c1-7
}

# Set the TOOLCHAIN_BUILD_ID before calling init.sh, so that the new Kudu build is
# associated with the specified toolchain.
: ${TOOLCHAIN_BUILD_ID=$(get_impala_master_toolchain_id)}
export TOOLCHAIN_BUILD_ID

: ${KUDU_VERSION=$(get_kudu_master_hash)}
export KUDU_VERSION

: ${BUILD_LABEL?Build label environment variable must be set.}
export BUILD_LABEL

# Set up the environment. Do not call init-compiler.sh yet because it would build the
# compiler and other build tools, all of which will be downloaded by this script.
source ./init.sh

# Output the build label and versions.
echo "BUILD_LABEL=${BUILD_LABEL}"
echo "TOOLCHAIN_BUILD_ID=${TOOLCHAIN_BUILD_ID}"
echo "KUDU_VERSION=${KUDU_VERSION}"

# Write the build ID and Kudu version to a file to be produced as a job artifact
# that can be sourced along with the impala-config.sh when building Impala.
# Note that the variable names are different in the impala-config.sh
BUILD_VERSIONS_FILE=$BUILD_DIR/kudu-build-info.sh
echo "IMPALA_TOOLCHAIN_BUILD_ID=${TOOLCHAIN_BUILD_ID}" > $BUILD_VERSIONS_FILE
echo "IMPALA_KUDU_VERSION=${KUDU_VERSION}" >> $BUILD_VERSIONS_FILE

# For unsupported platforms, build a fake package and exit.
if ! $SOURCE_DIR/source/kudu/build.sh is_supported_platform ; then
  build_fake_package kudu
  exit 0
fi

# Download all dependent packages.
for DL_PKG_NAME in $KUDU_DEPENDENCIES; do
  download_toolchain_dependency $DL_PKG_NAME
done

# Move downloaded files directly to BUILD_DIR
find $DL_DIR -type f -exec mv {} $TMP_DIR \;

echo "Extracting ..."
for file in $TMP_DIR/*.tar.gz; do tar --directory $TMP_DIR -zxf $file; done
rm -rf $DL_DIR

# Populate the 'check' directory so the packages aren't recompiled.
for dir in $TMP_DIR/*/
do
  # The name of the extracted directory, removing trailing and preceeding slashes,
  # e.g. "boost-1.57.0-p1".
  pkg_string=${dir%*/}
  pkg_string=${pkg_string##*/}
  touch $SOURCE_DIR/check/${pkg_string}

  # The version number for boost (and only boost) needs to be extracted so it can be
  # passed to the Kudu build.
  if [[ $pkg_string == "boost"* ]]; then
    export BOOST_VERSION=${pkg_string##boost-}
    echo "Using BOOST_VERSION=$BOOST_VERSION"
  fi
done

# Move the extracted packages to the build directory.
mv -f --backup=numbered $TMP_DIR/* $BUILD_DIR

# Now that all dependencies have been populated, run the Kudu build using the
# generic build script.
./build.sh kudu $KUDU_VERSION
