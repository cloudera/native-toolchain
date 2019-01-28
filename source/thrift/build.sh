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

  BISON_ROOT="${BUILD_DIR}"/bison-"${BISON_VERSION}"
  BOOST_ROOT="${BUILD_DIR}"/boost-"${BOOST_VERSION}"
  OPENSSL_ROOT="${BUILD_DIR}"/openssl-"${OPENSSL_VERSION}"
  ZLIB_ROOT="${BUILD_DIR}"/zlib-"${ZLIB_VERSION}"

  read OPENSSL_MAJ_VER OPENSSL_MIN_VER OPENSSL_PATCH_VER <<< `openssl version |  \
      sed -r 's/^OpenSSL ([0-9]+)\.([0-9]+)\.([0-9a-z]+).*/\1 \2 \3/'`
  # Build with system openssl if the system openssl version >= 1.0.1. Build with the
  # bundled openssl otherwise.
  if [[ "${PRODUCTION}" -eq "0" || "${OSTYPE}" == "darwin"* || \
      "${OPENSSL_MAJ_VER}" == "0" || \
      ( "${OPENSSL_MIN_VER}" ==  "0" &&  "$OPENSSL_PATCH_VER" < "1" ) ]]; then
    OPENSSL_ARGS=--with-openssl="${OPENSSL_ROOT}"
    export LDFLAGS="-L${OPENSSL_ROOT}/lib ${LDFLAGS}"
    # This is required for autoconf to detect "GNU libc compatible malloc"
    export LD_LIBRARY_PATH="${OPENSSL_ROOT}/lib:${LD_LIBRARY_PATH:-}"
  else
    OPENSSL_ARGS=
  fi

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
  PATH="${BISON_ROOT}"/bin:"${PATH}" \
    PY_PREFIX="${LOCAL_INSTALL}"/python \
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
    ${OPENSSL_ARGS} \
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
  wrap make install # Thrift 0.9.0 doesn't build with -j${BUILD_THREADS}
  cd contrib/fb303
  rm -f config.cache
  chmod 755 ./bootstrap.sh
  wrap ./bootstrap.sh --with-boost="${BOOST_ROOT}"
  wrap chmod 755 configure
  CPPFLAGS="-I${LOCAL_INSTALL}/include" PY_PREFIX="${LOCAL_INSTALL}"/python wrap ./configure \
    --with-boost="${BOOST_ROOT}" \
    --with-java=no --with-php=no --prefix="${LOCAL_INSTALL}" \
    --with-thriftpath="${LOCAL_INSTALL}" ${OPENSSL_ARGS}
  wrap make -j"${BUILD_THREADS}" install
  finalize_package_build "${PACKAGE}" "${PACKAGE_VERSION}"
fi
