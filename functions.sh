#!/usr/bin/env bash
# Copyright 2012 Cloudera Inc.
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

# cleans and rebuilds thirdparty/. The Impala build environment must be set up
# by bin/impala-config.sh before running this script.

# Exit on non-true return value
set -e
# Exit on reference to uninitialized variable
set -u

function prepare() {
  PACKAGE="$(basename $1)"; PACKAGE=`echo "${PACKAGE}" | awk '{print toupper($0)}'`
  PACKAGE_VERSION="${PACKAGE}_VERSION"
  # Replace potential - with _
  PACKAGE_VERSION="${PACKAGE_VERSION//-/_}"
  PACKAGE_VERSION="${!PACKAGE_VERSION}"
  PACKAGE_STRING="$PACKAGE-$PACKAGE_VERSION"
}

# Build helper function that sets the necessary environment variables
# that can be used per build
function header() {
  echo "#######################################################################"
  echo "# Building: ${1}-${2}"

  # Package name might be upper case
  LPACKAGE=`echo "${1}" | awk '{print tolower($0)}'`
  cd $SOURCE_DIR/source/$LPACKAGE

  LOCAL_INSTALL=$BUILD_DIR/$LPACKAGE-$2
  BUILD_LOG=$SOURCE_DIR/check/$LPACKAGE-$2.log

  # Extract the sources
  if [ -f $LPACKAGE-$2.tar.gz ]; then
    tar zxf $LPACKAGE-$2.tar.gz
    DIR=$LPACKAGE-$2
  elif [ -f $LPACKAGE-$2.tgz ]; then
    tar zxf $LPACKAGE-$2.tgz
    DIR=$LPACKAGE-$2
  elif [ -f $LPACKAGE-$2.src.tar.gz ]; then
    tar zxf $LPACKAGE-$2.src.tar.gz
    DIR=$LPACKAGE-$2.src
  elif [ -f $LPACKAGE-src-$2.tar.gz ]; then
    tar zxf $LPACKAGE-src-$2.tar.gz
    DIR=$LPACKAGE-src-$2
  elif [ -f $LPACKAGE-$2.zip ]; then
    unzip -o $LPACKAGE-$2.zip
    DIR=$LPACKAGE-$2
  else
    DIR=$LPACKAGE-$2
  fi


  # Depending how ugly things are packaged we might have directories that are different
  # from the archive name, looking at you boost
  RDIR="${DIR//-/_}"; RDIR="${RDIR//./_}"
  if [ -d "$DIR" ]; then
    cd $DIR
  elif [ -d "${RDIR}" ]; then
    cd $RDIR
  else
    cd $LPACKAGE
  fi
}

function footer() {
  touch $SOURCE_DIR/check/$1-$2
  echo "# Build Complete ${1}-${2}"
  echo "#######################################################################"
}


# Check if environment variables BUILD_ALL=0 and a variable of the
# name PACKAGE_NAME_VERSION is set indicating that this package needs
# to be build.
function needs_build_package() {

  if [ ! -f $SOURCE_DIR/check/$PACKAGE_STRING ]; then
    return 0
  fi

  # First check if the build_all variable is set or not
  : ${BUILD_ALL=0}

  ENV_NAME="BUILD_${PACKAGE}"
  ENV_NAME=${!ENV_NAME=0}

  if [ $BUILD_ALL -eq 0 ] && [ $ENV_NAME -eq 1 ]; then
    return 0 # Build package
  else
    return 1 # Dont build this package
  fi
}
