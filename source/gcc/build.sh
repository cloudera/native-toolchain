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

GCC_MAJOR_VERSION=$(echo $GCC_VERSION | cut -d. -f1)

# Download the same dependencies that would have been downloaded by
# gcc's ./contrib/download_prerequisites script.
if [[  $GCC_MAJOR_VERSION == '10' ]]; then
  MPFR_VERSION=3.1.4
  GMP_VERSION=6.1.0
  MPC_VERSION=1.0.3
  ISL_VERSION=0.18
  CLOOG_VERSION=0.18.1
else
  echo "Unknown gcc version $GCC_VERSION - don't know which dependencies to download"
  exit 1
fi
function download_gcc_prerequisites() {
  download_dependency $PACKAGE "mpfr-${MPFR_VERSION}.tar.bz2" .
  tar xjf "mpfr-${MPFR_VERSION}.tar.bz2"
  ln -s mpfr-${MPFR_VERSION} mpfr

  download_dependency $PACKAGE "gmp-${GMP_VERSION}.tar.bz2" .
  tar xjf "gmp-${GMP_VERSION}.tar.bz2"
  ln -s gmp-${GMP_VERSION} gmp

  download_dependency $PACKAGE "mpc-${MPC_VERSION}.tar.gz" .
  tar xzf "mpc-${MPC_VERSION}.tar.gz"
  ln -s mpc-${MPC_VERSION} mpc

  download_dependency $PACKAGE "isl-${ISL_VERSION}.tar.bz2" .
  tar xjf "isl-${ISL_VERSION}.tar.bz2"
  ln -s isl-${ISL_VERSION} isl

  download_dependency $PACKAGE "cloog-${CLOOG_VERSION}.tar.gz" .
  tar xzf "cloog-${CLOOG_VERSION}.tar.gz"
  ln -s cloog-${CLOOG_VERSION} cloog
}

if [ ! -f $SOURCE_DIR/check/$PACKAGE_STRING ]; then
  download_dependency $PACKAGE "${PACKAGE_STRING}.tar.gz" $THIS_DIR

  # The call to setup_package_build() changes into the right directory, so it
  # needs to happen before downloading the remaining prerequisites.
  setup_package_build $PACKAGE $PACKAGE_VERSION

  # We apply the patches manually here (instead of bumping the patch level) because
  # some components (boost) fail to compile with a modified gcc version.
  if [[ $GCC_VERSION = '10.4.0' ]]; then
    PATCH_DIR=${THIS_DIR}/gcc-${PACKAGE_VERSION}-patches
    apply_patches 1 $PATCH_DIR
  fi

  download_gcc_prerequisites

  cd ..
  mkdir -p build-${GCC_VERSION}
  cd build-${GCC_VERSION}

  # SLES12 tries to use the system linker, even though our modified
  # binutils is on the PATH. It's unclear what is going on, but this
  # forces it to use our linker.
  export LD=${BUILD_DIR}/binutils-${BINUTILS_VERSION}/bin/ld

  wrap ../gcc-$GCC_VERSION/configure --prefix=$LOCAL_INSTALL \
    --enable-languages=c,c++ --disable-multilib \
    --with-build-config=bootstrap-debug --enable-linker-build-id
  # Use 'profiledbootstrap' to build GCC with profile-guided optimization
  wrap make -j${BUILD_THREADS:-4} --load-average=${BUILD_THREADS:-4} profiledbootstrap
  wrap make install
  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
