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

source "${SOURCE_DIR}"/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare "${THIS_DIR}"

if needs_build_package ; then
  # Download the dependency from S3
  download_dependency "${PACKAGE}" "${PACKAGE_STRING}.tar.gz" "${THIS_DIR}"

  setup_package_build "${PACKAGE}" "${PACKAGE_VERSION}"

  BOOST_ROOT="${BUILD_DIR}"/boost-"${BOOST_VERSION}"
  ZLIB_ROOT="${BUILD_DIR}"/zlib-"${ZLIB_VERSION}"
  PYTHON_ROOT="${BUILD_DIR}"/python-"${PYTHON_VERSION}"

  if [[ -d "${PIC_LIB_PATH:-}" ]]; then
    PIC_LIB_OPTIONS="--with-zlib=${PIC_LIB_PATH}"
  fi

  if [[ "${OSTYPE}" == "darwin"* ]]; then
    wrap aclocal -I ./aclocal
    wrap glibtoolize --copy
    wrap autoconf
  else
     # Based on https://github.com/facebook/fbthrift/issues/222
     # but we don't run autoconf.
     sed -i 's/BN_init/BN_new/g' configure
   fi


  # LEXLIB= is a Workaround /usr/lib64/libfl.so: undefined reference to `yylex'
  PYTHON="${PYTHON_ROOT}"/bin/python
  PY_PREFIX="${LOCAL_INSTALL}"/python
  PATH="${PATH}" \
    PYTHON="${PYTHON}" \
    PY_PREFIX="${PY_PREFIX}" \
    wrap ./configure \
    LEXLIB= \
    --with-pic \
    --prefix="${LOCAL_INSTALL}" \
    --enable-tutorial=no \
    --with-c_glib=no \
    --with-php=no \
    --with-java=no \
    --with-perl=no \
    --with-erlang=no \
    --with-csharp=no \
    --with-ruby=no \
    --with-haskell=no \
    --with-erlang=no \
    --with-d=no \
    --with-boost="${BOOST_ROOT}" \
    --with-zlib="${ZLIB_ROOT}" \
    --with-nodejs=no \
    --with-lua=no \
    --with-go=no \
    --with-qt4=no \
    --with-libevent=no \
    ${PIC_LIB_OPTIONS:-} \
    ${CONFIGURE_FLAG_BUILD_SYS}
  # The error code is zero if one or more libraries can be built. To ensure that C++
  # and python libraries are built the output should be checked.
  if ! grep -q "Building C++ Library \.* : yes" "${BUILD_LOG}"; then
    echo "Thrift cpp lib configuration failed."
    exit 1
  fi
  if ! grep -q "Building Python Library \.* : yes" "${BUILD_LOG}"; then
    echo "Thrift python lib configuration failed."
    exit 1
  fi
  add_gcc_to_ld_library_path
  wrap make -j"${BUILD_THREADS:-4}" install
  cd contrib/fb303
  rm -f config.cache
  chmod 755 ./bootstrap.sh
  wrap ./bootstrap.sh --with-boost="${BOOST_ROOT}"
  wrap chmod 755 configure
  CPPFLAGS="-I${LOCAL_INSTALL}/include" PY_PREFIX="${PY_PREFIX}" PYTHON="${PYTHON}" wrap ./configure \
    --with-boost="${BOOST_ROOT}" \
    --with-java=no --with-php=no --with-cpp=no --prefix="${LOCAL_INSTALL}" \
    --with-thriftpath="${LOCAL_INSTALL}"
  wrap make -j"${BUILD_THREADS}" install

  # Fake the share/fb303/if
  mkdir -p ${LOCAL_INSTALL}/share/fb303/if
  cp if/fb303.thrift ${LOCAL_INSTALL}/share/fb303/if

  # Ensure that we've compiled the fastbinary shared object
  # Some distros place site-packages on lib and others do so in lib64
  PYTHONPATH=$(find "${PY_PREFIX}" -type d -name 'site-packages' -type d|tr '\n' ':') \
    wrap "${PYTHON}" -c 'import thrift.protocol.fastbinary'
  finalize_package_build "${PACKAGE}" "${PACKAGE_VERSION}"
fi
