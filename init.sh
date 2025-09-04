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

set -e
set -u
set -o pipefail

# This script exports the following environment variables:
#  - ARCH_NAME
#  - BINUTILS_VERSION
#  - BUILD_LABEL
#  - BUILD_THREADS
#  - CLEAN
#  - CLEAN_TMP_AFTER_BUILD
#  - CMAKE_VERSION
#  - COMPILER
#  - COMPILER_VERSION
#  - CONFIGURE_FLAG_BUILD_SYS
#  - DEBUG
#  - DOWNLOAD_CCACHE
#  - FAIL_ON_PUBLISH
#  - GCC_VERSION
#  - MACOSX_DEPLOYMENT_TARGET
#  - OS_NAME
#  - OS_VERSION
#  - PATH
#  - PRODUCTION
#  - PUBLISH_DEPENDENCIES
#  - SOURCE_DIR
#  - SYSTEM_CMAKE
#  - SYSTEM_GCC
#  - TOOLCHAIN_BUILD_ID
#
# Also see init-compiler.sh which initializes the compiler environment, including
# bootstrapping the compiler if necessary.

# If set to 1 will use -x flag in bash and print the output to stdout and write
# it to the log file. If set to 0 only writes to the log file.
: ${DEBUG=0}
export DEBUG

# If set to 1, will fail the build if the artifacts could not be published.
: ${FAIL_ON_PUBLISH=1}
export FAIL_ON_PUBLISH

# If set to 1, the script will upload the artifacts to the internal artifactory and s3
# this is functionally the same as:
# PUBLISH_DEPENDENCIES_S3=1 PUBLISH_DEPENDENCIES_ARTIFACTORY=1
: ${PUBLISH_DEPENDENCIES=0}
export PUBLISH_DEPENDENCIES

# A flag that can be used to trigger particular behavior. PRODUCTION=1 is how
# the toolchain is used for packaging native products.
: ${PRODUCTION=1}
export PRODUCTION

# Clean the entire native-toolchain git repo before building.
: ${CLEAN=0}
export CLEAN

# Clean the source/<package> directory after building each package
# This significantly reduces the disk space required for the build.
: ${CLEAN_TMP_AFTER_BUILD=0}
export CLEAN_TMP_AFTER_BUILD

: ${BINUTILS_VERSION=2.42}
export BINUTILS_VERSION

# Flag to determine the system compiler is used
: ${SYSTEM_GCC=0}
export SYSTEM_GCC

: ${GCC_VERSION=10.4.0}
export GCC_VERSION

: ${SYSTEM_CMAKE=0}
export SYSTEM_CMAKE

: ${CMAKE_VERSION=3.22.2}
export CMAKE_VERSION

set -x
# Set the build target platform from the Jenkins environment if it was not
# already set, or fall back to 'generic'.
: ${BUILD_TARGET_LABEL="generic"}
: ${BUILD_LABEL=$BUILD_TARGET_LABEL}
export BUILD_LABEL
set +x

# Determine the number of build threads
BUILD_THREADS=$(getconf _NPROCESSORS_ONLN)
export BUILD_THREADS

# SOURCE DIR for the current script
export SOURCE_DIR="$( cd "$( dirname "$0" )" && pwd )"

: ${USE_CCACHE=1}
export USE_CCACHE

# When set, a ccache directory from a previous run is downloaded from the native-toolchain bucket.
# Failing to download this directory doesn't abort the build. If the UPLOAD_CCACHE makefile variable
# (not exported in this file, because we only update ccache when we build all platforms) is set to 1,
# CCACHE_DIR is tarred and uploaded at the end of a full build.
: ${DOWNLOAD_CCACHE=0}
export DOWNLOAD_CCACHE

: ${CCACHE_MAXSIZE=50G}
export CCACHE_MAXSIZE

: ${CCACHE_DIR=$SOURCE_DIR/ccache}
export CCACHE_DIR

# Default ccache_compilercheck is mtime, which considers CC's mtime + size
# to determine if there's a hit. Setting CCACHE_COMPILERCHECK to 'content'
# uses the hash of the compiler instead.
export CCACHE_COMPILERCHECK=${CCACHE_COMPILERCHECK:-content}

export CCACHE_COMPRESS=1

if [[ $DEBUG -eq 1 ]]; then
  set -x
fi

# Load functions
source $SOURCE_DIR/functions.sh

: ${TOOLCHAIN_BUILD_ID=$(generate_build_id)}
export TOOLCHAIN_BUILD_ID
echo "Build ID is $TOOLCHAIN_BUILD_ID"

# Make sure the necessary file system layout exists
prepare_build_dir

# Check Platform and build the correct release name.
if [[ "$OSTYPE" =~ ^linux ]]; then
  # /etc/os-release is present in all supported distributions
  if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: /etc/os-release is not present"
    exit 1
  fi
  OS_NAME_VERSION=$(source /etc/os-release && printf "$ID\n$VERSION_ID")
  # Convert to lowercase, remove new lines, and trim minor version.
  OS_NAME_VERSION=$(tr "A-Z" "a-z" <<< "$OS_NAME_VERSION" | tr "\n" " " | cut -d. -f1 )
  # These matches are based on the database of /etc/os-release files at
  # https://github.com/chef/os_release
  # (In particular, the ID field)
  case "$OS_NAME_VERSION" in
    centos* | rhel* | rocky* | almalinux*) OS_NAME=rhel;;
    debian*) OS_NAME=debian;;
    sles*) OS_NAME=suse;;
    ubuntu*) OS_NAME=ubuntu;;
    *) echo "Warning: Unable to detect operating system" 1>&2
       OS_NAME=unknown;;
  esac
  OS_VERSION=$(echo "$OS_NAME_VERSION" | awk '{ print $NF }')
elif [[ "$OSTYPE" == "darwin"* ]]; then
  OS_NAME="darwin"
  OS_VERSION=`sw_vers -productVersion`

  # The deployment target environment variable is needed to silence warning and
  # errors on OS X wrt rpath settings and libary dependencies.
  export MACOSX_DEPLOYMENT_TARGET=$(echo $OS_VERSION | sed -E 's/(10.[0-9]+).*/\1/')
fi

#Set Architecture of the platform
ARCH_NAME=`uname -p`
export ARCH_NAME

if [[ "$ARCH_NAME" == "ppc64le" ]]; then
  export CONFIGURE_FLAG_BUILD_SYS="--build=powerpc64le-unknown-linux-gnu"
elif [[ "$ARCH_NAME" == "aarch64" ]]; then
  export CONFIGURE_FLAG_BUILD_SYS="--build=aarch64-unknown-linux-gnu"
else
  export CONFIGURE_FLAG_BUILD_SYS=
fi

if [[ $SYSTEM_GCC -eq 0 ]]; then
  COMPILER="gcc"
  COMPILER_VERSION=$GCC_VERSION
else
  COMPILER="gcc"
  COMPILER_VERSION="system"
fi

export COMPILER
export COMPILER_VERSION
export CLEAN
export DEBUG
export OS_NAME
export OS_VERSION
export PATH
