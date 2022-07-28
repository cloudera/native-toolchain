#!/usr/bin/env bash
# Copyright 2015 Cloudera Inc.
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

export SOURCE_DIR="$( cd "$( dirname "$0" )" && pwd )"

# Set up the environment configuration.
source ./init.sh
# Configure the compiler/linker flags, bootstrapping tools if necessary.
source ./init-compiler.sh

function build() {
  echo "Requesting build of $1 $2"
  PACKAGE=`echo "$1" | awk '{print toupper($0)}'`
  VAR_NAME="${PACKAGE//-/_}_VERSION"
  VAR_PACKAGE="BUILD_${PACKAGE//-/_}"
  export $VAR_NAME=$2
  export BUILD_ALL=0
  export $VAR_PACKAGE=1
  $SOURCE_DIR/source/$1/build.sh
}

# Check that command line arguments were passed correctly.
if [ "$#" == "0" ]; then
  echo "Usage $0 package1 version1 [package2 version2 ...]"
  echo "      Builds one or more packages identified by package_name"
  echo "      and version identifier."
  echo ""
  false
fi

while (( "$#" )); do
  package=$1
  shift
  if [ "$#" == "0" ]; then
    echo "Version not found for ${package}."
    false
  fi
  version=$1
  shift
  build $package $version
done
