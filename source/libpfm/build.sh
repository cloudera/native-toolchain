#!/usr/bin/env bash
# Copyright 2024 Cloudera Inc.
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

if needs_build_package ; then
  # Download the dependency from S3
  download_dependency $PACKAGE "${PACKAGE_STRING}.tar.gz" $THIS_DIR

  setup_package_build $PACKAGE $PACKAGE_VERSION

  wrap make VERBOSE=1 -j$BUILD_THREADS
  wrap make PREFIX=$LOCAL_INSTALL install
  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
