#!/usr/bin/env bash
# Copyright 2023 Cloudera Inc.
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

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR

if needs_build_package ; then
  if [[ -z "${JAVA_HOME:-}" ]]; then
    if [ -n "$(which javac)" ]; then
      export JAVA_HOME="$(dirname $(dirname $(readlink -f $(which javac))))"
    else
      echo "JAVA_HOME must be set"
      exit 1
    fi
  fi

  SOURCE_TARBALL="release-${PACKAGE_VERSION}.tar.gz"
  UNPACK_DIR="hadoop-rel-release-${PACKAGE_VERSION}"
  download_dependency $PACKAGE $SOURCE_TARBALL $THIS_DIR
  setup_package_build $PACKAGE $PACKAGE_VERSION $SOURCE_TARBALL $UNPACK_DIR

  # Hadoop uses *_HOME environment variables to find dependencies.
  export PROTOBUF_HOME=$BUILD_DIR/protobuf-${PROTOBUF_VERSION}
  export SNAPPY_HOME=$BUILD_DIR/snappy-${SNAPPY_VERSION}
  export ZLIB_HOME=$BUILD_DIR/zlib-${ZLIB_VERSION}
  export ZSTD_HOME=$BUILD_DIR/zstd-${ZSTD_VERSION}

  # Use a local maven repository to avoid issues building in a container.
  # Builds only subprojects that produce native libraries.
  wrap mvn --batch-mode -Dmaven.repo.local=$THIS_DIR/.m2/repository clean compile \
      -Pnative -DskipTests -DskipShade -Dmaven.javadoc.skip=true -Drequire.openssl \
      -Drequire.snappy -Dsnappy.prefix=${SNAPPY_HOME} \
      -Drequire.zstd -Dzstd.prefix=${ZSTD_HOME} \
      -projects :hadoop-common,:hadoop-hdfs-native-client,:hadoop-mapreduce-client-nativetask

  # Copy the libraries we currently use to minimize archive size. Omits libhdfspp, which
  # depends on libprotobuf.
  NATIVE_LIBS=$LOCAL_INSTALL/lib
  mkdir -p $NATIVE_LIBS
  BUILD_PATH=target/native/target/usr/local/lib
  cp $THIS_DIR/$UNPACK_DIR/hadoop-hdfs-project/hadoop-hdfs-native-client/$BUILD_PATH/libhdfs.* $NATIVE_LIBS/
  cp $THIS_DIR/$UNPACK_DIR/hadoop-common-project/hadoop-common/$BUILD_PATH/libhadoop.* $NATIVE_LIBS/
  NATIVETASK_PATH=hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-nativetask
  cp $THIS_DIR/$UNPACK_DIR/$NATIVETASK_PATH/$BUILD_PATH/libnativetask.* $NATIVE_LIBS/
  # Copy libraries used by hadoop libs. libsnappy is dynamically linked, while libzstd is
  # loaded at runtime. They're in lib/ on Ubuntu and lib64/ on RedHat.
  SNAPPY_LIB_DIR=$SNAPPY_HOME/lib
  if [[ ! -f "${SNAPPY_LIB_DIR}/libsnappy.so" ]]; then
    SNAPPY_LIB_DIR=$SNAPPY_HOME/lib64
  fi
  cp $SNAPPY_LIB_DIR/libsnappy.so* $NATIVE_LIBS/
  ZSTD_LIB_DIR=$ZSTD_HOME/lib
  if [[ ! -f "${ZSTD_LIB_DIR}/libzstd.so" ]]; then
    ZSTD_LIB_DIR=$ZSTD_HOME/lib64
  fi
  cp $ZSTD_LIB_DIR/libzstd.so* $NATIVE_LIBS/
  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
