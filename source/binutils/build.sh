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

set -euo pipefail

source $SOURCE_DIR/functions.sh
THIS_DIR="$(cd "$(dirname "$0")" && pwd)"
prepare $THIS_DIR

# Because this is being built before we've switched over to the toolchain
# compiler, it doesn't get our custom CFLAGS/CXXFLAGS. By default, binutils
# will build with -O2. To get a bit more optimization, force it to use -O3.
export CFLAGS="-fPIC -O3"
export CXXFLAGS="-fPIC -O3"

if needs_build_package ; then
  # Download the dependency from S3
  download_dependency $PACKAGE "${PACKAGE_STRING}.tar.gz" $THIS_DIR

  setup_package_build $PACKAGE $PACKAGE_VERSION
  # --disable-x86-relax-relocations: prevent assembler from emitting relocations like
  #   R_X86_64_GOTPCRELX, which are not supported by pre-2.26 binutils (e.g. system
  #   linkers and utilities on various Linux distributions). This can be reenabled with
  #   the assembler flag -mrelax-relocations=yes if desired.
  #   see https://sourceware.org/bugzilla/show_bug.cgi?id=19520 and IMPALA-5025.
  wrap ./configure --enable-gold --enable-plugins --disable-x86-relax-relocations \
      --prefix=$LOCAL_INSTALL
  wrap make VERBOSE=1 -j$BUILD_THREADS
  wrap make install
  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
