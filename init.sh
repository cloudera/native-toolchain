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
#  - AUTOCONF_VERSION
#  - AUTOMAKE_VERSION
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
#  - FAIL_ON_PUBLISH
#  - GCC_VERSION
#  - LIBTOOL_VERSION
#  - MACOSX_DEPLOYMENT_TARGET
#  - OS_NAME
#  - OS_VERSION
#  - PATH
#  - PRODUCTION
#  - PUBLISH_DEPENDENCIES
#  - RELEASE_NAME
#  - SOURCE_DIR
#  - SYSTEM_AUTOTOOLS
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
: ${FAIL_ON_PUBLISH=0}
export FAIL_ON_PUBLISH

# If set to 1, the script will upload the artifacts to the internal artifactory
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

: ${BINUTILS_VERSION=2.26.1}
export BINUTILS_VERSION

# Flag to determine the system compiler is used
: ${SYSTEM_GCC=0}
export SYSTEM_GCC

: ${GCC_VERSION=4.9.2}
export GCC_VERSION

: ${SYSTEM_CMAKE=0}
export SYSTEM_CMAKE

: ${CMAKE_VERSION=3.8.2-p1}
export CMAKE_VERSION

: ${SYSTEM_AUTOTOOLS=0}
export SYSTEM_AUTOTOOLS

: ${AUTOCONF_VERSION=2.69}
export AUTOCONF_VERSION

: ${AUTOMAKE_VERSION=1.14.1-p1}
export AUTOMAKE_VERSION

: ${LIBTOOL_VERSION=2.4.2}
export LIBTOOL_VERSION

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

# BUILD_HISTORICAL determines whether buildall.sh should build all historical versions.
# A historical version is one that is not depended on by new development and therefore
# should not be rebuilt for new platforms, compilers or toolchain revisions.
: ${BUILD_HISTORICAL=0}

# SOURCE DIR for the current script
export SOURCE_DIR="$( cd "$( dirname "$0" )" && pwd )"

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

# Check Platform and build the correct release name. The RELEASE_NAME is used
# when publishing the artifacts to the artifactory.
if [[ "$OSTYPE" =~ ^linux ]]; then
  if ! which lsb_release &>/dev/null; then
    echo Unable to find the 'lsb_release' command. \
        Please ensure it is available in your PATH. 1>&2
    exit 1
  fi
  OS_NAME_VERSION=$(lsb_release -sir 2>&1)
  # Convert to lowercase, remove new lines, and trim minor version.
  OS_NAME_VERSION=$(tr "A-Z" "a-z" <<< "$OS_NAME_VERSION" | tr "\n" " " | cut -d. -f1 )
  case "$OS_NAME_VERSION" in
    # "enterprise" is Oracle
    centos* | enterprise* | redhat*) OS_NAME=rhel;;
    debian*) OS_NAME=debian;;
    suse*) OS_NAME=suse;;
    ubuntu*) OS_NAME=ubuntu;;
    *) echo "Warning: Unable to detect operating system" 1>&2
       OS_NAME=unknown;;
  esac
  OS_VERSION=$(echo "$OS_NAME_VERSION" | awk '{ print $NF }')

  RELEASE_NAME=`lsb_release -r -i`
elif [[ "$OSTYPE" == "darwin"* ]]; then
  RELEASE_NAME="OSX-$(sw_vers -productVersion)"
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
export RELEASE_NAME
