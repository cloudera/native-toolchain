#!/bin/bash
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
set -eu

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR


SOURCE_VERSION=${PACKAGE_VERSION}
if [[ $PACKAGE_VERSION =~ "-no-asserts" ]]; then
  SOURCE_VERSION=${PACKAGE_VERSION%-no-asserts}
elif [[ $PACKAGE_VERSION =~ "-asserts" ]]; then
  SOURCE_VERSION=${PACKAGE_VERSION%-asserts}
elif [[ $PACKAGE_VERSION =~ "-debug" ]]; then
  SOURCE_VERSION=${PACKAGE_VERSION%-debug}
fi

ARCHIVE_EXT="tar.xz"
if [[ "$PACKAGE_VERSION" =~ "3.3" ]]; then
  # Older versions with distributed in tar.gz archives.
  ARCHIVE_EXT="tar.gz"
fi

if needs_build_package ; then
  download_dependency $PACKAGE "cfe-${SOURCE_VERSION}.src.${ARCHIVE_EXT}" $THIS_DIR
  download_dependency $PACKAGE "clang-tools-extra-${SOURCE_VERSION}.src.${ARCHIVE_EXT}" $THIS_DIR
  download_dependency $PACKAGE "compiler-rt-${SOURCE_VERSION}.src.${ARCHIVE_EXT}" $THIS_DIR
  download_dependency $PACKAGE "llvm-${SOURCE_VERSION}.src.${ARCHIVE_EXT}" $THIS_DIR

  if [[ "$PACKAGE_VERSION" =~ "3.3" ]]; then
    . $SOURCE_DIR/source/llvm/build-3.3.sh
    cd $SOURCE_DIR/source/llvm
    build_llvm_33
  else
    . $SOURCE_DIR/source/llvm/build-source-tarball.sh
    cd $SOURCE_DIR/source/llvm
    build_llvm
  fi
fi
