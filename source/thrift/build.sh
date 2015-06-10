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

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR

if needs_build_package ; then
  header $PACKAGE $PACKAGE_VERSION

  BOOST_ROOT=$BUILD_DIR/boost-$BOOST_VERSION
  ZLIB_ROOT=$BUILD_DIR/zlib-$ZLIB_VERSION
  LIBEVENT_ROOT=$BUILD_DIR/libevent-$LIBEVENT_VERSION

  if [ -d "${PIC_LIB_PATH:-}" ]; then
    PIC_LIB_OPTIONS="--with-zlib=${PIC_LIB_PATH} "
  fi
  JAVA_PREFIX=${LOCAL_INSTALL}/java PY_PREFIX=${LOCAL_INSTALL}/python \
    ./configure --with-pic --prefix=${LOCAL_INSTALL} \
    --with-php=no --with-java=no --with-perl=no --with-erlang=no --with-csharp=no \
    --with-ruby=no --with-haskell=no --with-erlang=no --with-d=no \
    --with-boost=${BOOST_ROOT} \
    --with-zlib=${ZLIB_ROOT} \
    --with-libevent=${LIBEVENT_ROOT} \
    --with-go=no --with-qt4=no --with-libevent=no ${PIC_LIB_OPTIONS:-} >> $BUILD_LOG 2>&1
  make >> $BUILD_LOG 2>&1
  make install >> $BUILD_LOG 2>&1
  cd contrib/fb303
  rm -f config.cache
  chmod 755 ./bootstrap.sh
  ./bootstrap.sh >> $BUILD_LOG 2>&1
  chmod 755 configure >> $BUILD_LOG 2>&1
  CPPFLAGS="-I${LOCAL_INSTALL}/include" PY_PREFIX=${LOCAL_INSTALL}/python ./configure \
    --with-boost=${BOOST_ROOT} \
    --with-java=no --with-php=no --prefix=${LOCAL_INSTALL} \
    --with-thriftpath=${LOCAL_INSTALL} >> $BUILD_LOG 2>&1
  make >> $BUILD_LOG 2>&1
  make install >> $BUILD_LOG 2>&1

  footer $PACKAGE $PACKAGE_VERSION
fi
