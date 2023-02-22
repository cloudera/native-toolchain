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

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR


if needs_build_package ; then
  ARCHIVE_FILE="${PACKAGE_STRING}.tar.xz"
  download_dependency $PACKAGE $ARCHIVE_FILE $THIS_DIR

  setup_package_build $PACKAGE $PACKAGE_VERSION $ARCHIVE_FILE "Python-${PYTHON_VERSION}"

  # build Python with bzip2
  BZIP2_ROOT="${BUILD_DIR}"/bzip2-"${BZIP2_VERSION}"

  # Python bakes the name of the C and C++ compilers into the package to be used for
  # building native packages. We want the defaults to be just the name of the compiler,
  # e.g. "gcc" and "g++" without any additional path, particularly not any temporary
  # directories, because consumers of the toolchain will likely install the compilers in
  # a different directory from the one used during our toolchain build.
  export PATH="$(dirname ${CC}):$(dirname ${CXX}):$PATH"
  CC=$(basename ${CC})
  CXX=$(basename ${CXX})

  # SLES12 puts the ncurses includes into a separate subdirectory under /usr/include,
  # which break readline if not put explicitly on the include path
  export CFLAGS="-I/usr/include/ncurses -I${BZIP2_ROOT}/include"
  export LDFLAGS="-L${BZIP2_ROOT}/lib"
  export LD_LIBRARY_PATH="${BZIP2_ROOT}/lib:${LD_LIBRARY_PATH:-}"
  # fastbinary expects ucs4. Without this, we get:
  # ImportError: /mnt/build/thrift-0.11.0-p2/python/lib/python2.7/site-packages/thrift/protocol/fastbinary.so: undefined symbol: PyUnicodeUCS2_DecodeUTF8
  wrap ./configure --prefix=$LOCAL_INSTALL --enable-unicode=ucs4
  wrap make -j${BUILD_THREADS:-4}
  wrap make install
  # Assert that important packages were built successfully. Some modules are changed in Python 3.
  if [ "${PYTHON_VERSION:0:1}" = "2" ]; then
    wrap $LOCAL_INSTALL/bin/python2 -c 'import bz2; import readline; from urllib2 import HTTPSHandler; from httplib import HTTPConnection'
  else
    wrap $LOCAL_INSTALL/bin/python3 -c 'import bz2; import readline; from urllib.request import HTTPSHandler; from http.client import HTTPConnection'
  fi
  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
