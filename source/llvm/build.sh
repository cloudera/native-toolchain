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
elif [[ $PACKAGE_VERSION =~ "-pgo" ]]; then
  SOURCE_VERSION=${PACKAGE_VERSION%-pgo}
fi

ARCHIVE_EXT="tar.xz"

function download_legacy_tarballs() {
  echo "Downloading LLVM 5 tarballs"
  download_dependency $PACKAGE "cfe-${SOURCE_VERSION}.src.${ARCHIVE_EXT}" $THIS_DIR
  download_dependency $PACKAGE "clang-tools-extra-${SOURCE_VERSION}.src.${ARCHIVE_EXT}" $THIS_DIR
  download_dependency $PACKAGE "compiler-rt-${SOURCE_VERSION}.src.${ARCHIVE_EXT}" $THIS_DIR
  download_dependency $PACKAGE "llvm-${SOURCE_VERSION}.src.${ARCHIVE_EXT}" $THIS_DIR
}

function unpack_legacy_tarballs() {
  # The legacy llvm source is composed of multiple archives, some of which are optional.
  # To allow unified patches across the entirety of the source, we extract all of the
  # desired archives in the appropriate places, and then use
  # setup_extracted_package_build, which can then apply patches across the whole
  # source tree.
  EXTRACTED_DIR="llvm-${SOURCE_VERSION}.src"
  TARGET_DIR="$PACKAGE_STRING.src"

  extract_archive "$THIS_DIR/llvm-${SOURCE_VERSION}.src.${ARCHIVE_EXT}"
  if [ "$EXTRACTED_DIR" != "$TARGET_DIR" ]; then
    mv "$EXTRACTED_DIR" "$TARGET_DIR"
  fi
  pushd "$TARGET_DIR"

  pushd tools
  # CLANG
  extract_archive ${THIS_DIR}/cfe-$SOURCE_VERSION.src.tar.xz
  mv cfe-$SOURCE_VERSION.src clang

  # CLANG Extras
  pushd clang/tools
  extract_archive ${THIS_DIR}/clang-tools-extra-$SOURCE_VERSION.src.tar.xz
  mv clang-tools-extra-$SOURCE_VERSION.src extra
  popd

  # COMPILER RT
  # Required for *Sanitizers and for using Clang's own C/C++ runtime.
  pushd ../projects
  extract_archive ${THIS_DIR}/compiler-rt-$SOURCE_VERSION.src.tar.xz
  mv compiler-rt-$SOURCE_VERSION.src compiler-rt
  popd

  popd # tools
  popd # $TARGET_DIR
}

function download_unified_tarball() {
  echo "Downloading LLVM 6+ unified tarball"
  download_dependency $PACKAGE "llvm-project-${SOURCE_VERSION}.src.${ARCHIVE_EXT}" $THIS_DIR
}

function unpack_unified_tarball() {
  EXTRACTED_DIR="llvm-project-${SOURCE_VERSION}.src"
  TARGET_DIR="$PACKAGE_STRING.src"

  extract_archive "$THIS_DIR/llvm-project-${SOURCE_VERSION}.src.${ARCHIVE_EXT}"
  if [ "$EXTRACTED_DIR" != "$TARGET_DIR" ]; then
    echo "Moving $EXTRACTED_DIR to $TARGET_DIR"
    mv "$EXTRACTED_DIR" "$TARGET_DIR"
  fi
}

if needs_build_package ; then
  cd $SOURCE_DIR/source/llvm
  if [[ $SOURCE_VERSION =~ ^5\.0\..* ]]; then
    USES_LEGACY_TARBALLS=true
  else
    # Unified "llvm-project" tarballs seem to be available on Github releases starting with
    # LLVM 7. They are available on the official download page starting with LLVM 10.
    # Either way, this is our preferred way to build newer LLVM releases.
    USES_LEGACY_TARBALLS=false
  fi

  # Cleanup possible leftovers
  rm -Rf "$THIS_DIR/${PACKAGE_STRING}.src"
  rm -Rf "$THIS_DIR/build-${PACKAGE_STRING}"

  HELPER_ARGS="-source_dir ${THIS_DIR}/$PACKAGE_STRING.src${PATCH_VERSION}"
  if $USES_LEGACY_TARBALLS ; then
    download_legacy_tarballs
    unpack_legacy_tarballs
    HELPER_ARGS+=" -source_dir_type legacy"
  else
    download_unified_tarball
    unpack_unified_tarball
    HELPER_ARGS+=" -source_dir_type unified"
  fi

  # Patches are based on source version. Pass to setup_extracted_package_build function
  # with this var.
  PATCH_DIR=${THIS_DIR}/llvm-${SOURCE_VERSION}-patches

  setup_extracted_package_build $PACKAGE $PACKAGE_VERSION $TARGET_DIR
  add_gcc_to_ld_library_path

  # Put ninja on the PATH to allow restricting the link concurrency. This makes a big
  # difference to the peak memory usage for a project as large as LLVM.
  PATH="${PATH}:${BUILD_DIR}/ninja-${NINJA_VERSION}/bin"

  # GCC 14 turned this warning into an error. Disable the error to keep this building.
  GCC_CFLAGS=" -Wno-error=implicit-function-declaration"

  if [[ "${PACKAGE_VERSION}" =~ "-pgo" ]]; then
    # Profile Guided Optimization only makes sense for a release build without asserts.
    # It performs three builds:
    # Build 1: Build LLVM with profile generation enabled
    # Build 2: Produce the profile by using LLVM from the first build to build LLVM again
    # Build 3: Build LLVM using the profile
    #
    # Build 1 and build 3 use the same build directory (removed between builds).
    # This ends up being the easiest way to have the compiler find and use the profile
    # information. If the build directories are different, then all the profile paths
    # need to be translated properly. -fprofile-prefix-path works for smaller projects,
    # but LLVM generates some include files that are placed in the build directory. This
    # trips the profile mismatch logic even though the files are identical. In the end,
    # it is easier to reuse the build directory, as that guarantees that every file is in
    # the same location.

    LLVM_BUILD_DIR="${THIS_DIR}/build-$PACKAGE_STRING"
    PROFILE_GEN_INSTALL_DIR="${THIS_DIR}/install-${PACKAGE_STRING}-profile-generate"
    PROFILE_OUT_DIR="${THIS_DIR}/profile-out-${PACKAGE_STRING}"
    # Clean up remanants of previous builds (though arguably some of this could be
    # incremental for hand-building)
    rm -rf ${LLVM_BUILD_DIR}
    rm -rf ${PROFILE_GEN_INSTALL_DIR}
    rm -rf ${PROFILE_OUT_DIR}

    (
      wrap echo "######################## Begin PGO Build #1 ########################"
      # Build 1: Build LLVM with profile generation enabled
      # This is symmetric to the final build. We want the flags to be identical to the
      # final build, except that we add flags to generate profiles.
      # -fprofile-generate tells the compiler to produce a binary that writes profiling
      # information. It needs to be passed to both the compiler and the linker.
      PROFILE_GEN_CFLAGS="-fprofile-generate"
      PROFILE_GEN_LDFLAGS="-fprofile-generate"

      if [[ "$(uname -m)" == "aarch64" ]]; then
        # ARM uses moutline-atomics and the profile generation requires the atomics
        # library to be linked in. Manually add the atomic library.
        PROFILE_GEN_LDFLAGS+=" -latomic"
      fi

      # The profile data is written as .gcda files. By default, these are put in
      # the same directory as the .o files. For these builds, the .o files are in
      # the build directory. It's easiest to wipe out the build directory when we
      # reuse it for the optimized build, so we need to have the profile information
      # written to a dedicated directory. This directory is specified by the
      # -fprofile-dir option.
      PROFILE_GEN_CFLAGS+=" -fprofile-dir=${PROFILE_OUT_DIR}"

      # This is using GCC, so add the GCC flags
      PROFILE_GEN_CFLAGS+="${GCC_CFLAGS}"

      # Turn off debug symbols for the regular release build. These symbols add 300+MB to
      # Impala's binary size. Oddly enough, the -asserts build doesn't have a similar
      # problem. This only builds clang and lld (skipping compiler-rt and clang-tools-extra).
      wrap ${THIS_DIR}/build-helper.sh ${HELPER_ARGS} \
        -build_dir "${LLVM_BUILD_DIR}" \
        -install_dir "${PROFILE_GEN_INSTALL_DIR}" \
        -release \
        -g0 \
        -add_cflags "${PROFILE_GEN_CFLAGS}" \
        -add_cxxflags "${PROFILE_GEN_CFLAGS}" \
        -add_ldflags "${PROFILE_GEN_LDFLAGS}" \
        -llvm_enable_projects "clang;lld"

      wrap echo "######################## End PGO Build #1 ########################"
    )

    (
      wrap echo "######################## Begin PGO Build #2 ########################"
      # Build 2: Produce the profile by compiling LLVM using itself
      # This wants to exercise optimization, so it uses a Release build with debug info
      # enabled (-g). It doesn't use RelWithDebInfo, because that is -O2 rather than -O3.
      # The debug info is not strictly necessary for codegen, but we use it for builds
      # that compile with Clang.
      PRODUCE_PROFILE_BUILD_DIR="${THIS_DIR}/build-${PACKAGE_STRING}-produce-profile"
      PRODUCE_PROFILE_INSTALL_DIR="${THIS_DIR}/install-${PACKAGE_STRING}-produce-profile"
      rm -rf ${PRODUCE_PROFILE_BUILD_DIR}
      rm -rf ${PRODUCE_PROFILE_INSTALL_DIR}

      # If we built lld, use it for the training to get some coverage.
      if $USES_LEGACY_TARBALLS ; then
          # We don't build lld for the legacy tarballs. It is not impossible, but historically
          # we haven't.
          LD_OVERRIDE_FLAGS=""
      else
          # For unified tarballs, we always build lld. To use lld, we need to put our lld on
          # the PATH and pass in the override flag (which uses LLVM_USE_LINKER).
          PATH="${PATH}:${PROFILE_GEN_INSTALL_DIR}/bin"
          LD_OVERRIDE_FLAGS="-ld_override lld"
      fi

      # Point to the toolchain GCC to use its libstdc++
      PRODUCE_PROFILE_FLAGS="--gcc-toolchain=${BUILD_DIR}/gcc-${GCC_VERSION}"
      wrap ${THIS_DIR}/build-helper.sh ${HELPER_ARGS} \
        -build_dir "${PRODUCE_PROFILE_BUILD_DIR}" \
        -install_dir "${PRODUCE_PROFILE_INSTALL_DIR}" \
        -release \
        -add_cflags "${PRODUCE_PROFILE_FLAGS}" \
        -add_cxxflags "${PRODUCE_PROFILE_FLAGS}" \
        -cc_override "${PROFILE_GEN_INSTALL_DIR}/bin/clang" \
        -cxx_override "${PROFILE_GEN_INSTALL_DIR}/bin/clang++" \
        ${LD_OVERRIDE_FLAGS} \
        -g

      # We don't actually need the binaries from this build, so go ahead and delete it.
      rm -rf "${PRODUCE_PROFILE_INSTALL_DIR}"
      rm -rf "${PRODUCE_PROFILE_BUILD_DIR}"
      wrap echo "######################## End PGO Build #2 ########################"
    )

    (
      wrap echo "######################## Begin PGO Build #3 ########################"
      # Build 3: Build the optimized LLVM using the profile
      # This is the final build, so this installs into the expected location for the
      # final build
      PROFILE_USE_INSTALL_DIR="${LOCAL_INSTALL}"
      rm -rf ${LLVM_BUILD_DIR}
      # We specify -fprofile-use and the -fprofile-dir that we used previously
      PROFILE_USE_CFLAGS="-fprofile-use -fprofile-dir=${PROFILE_OUT_DIR}"
      # By default, if something is not used in the profile data, GCC will optimize it
      # for size. The -fprofile-partial-training option instead optimizes it for speed
      # (as it would if it didn't have profile data). If the training step covered
      # things properly, optimizing for size would be the right answer. Since we're
      # training using an LLVM build and that is different from how we use it, optimizing
      # for speed would protect us from issues with this limited training.
      PROFILE_USE_CFLAGS+=" -fprofile-partial-training"

      # Some compiler configuration checks use -Werror while checking for certain
      # compiler features. Since -fprofile-use produces the -Wmissing-profile warning,
      # of these checks fail incorrectly. We don't want to specify -Wno-missing-profile
      # for all of our build, because these warnings are useful to have in the logs.
      # As a workaround, this uses CMAKE_REQUIRED_FLAGS to turn off the missing-profile
      # warning. CMAKE_REQUIRED_FLAGS flags are added to the compiler checks but not the
      # regular compilation.
      PROFILE_USE_EXTRA_CMAKE_ARGS='-DCMAKE_REQUIRED_FLAGS="-Wno-missing-profile"'

      # This is using GCC, so add the GCC flags
      PROFILE_GEN_CFLAGS+="${GCC_CFLAGS}"

      # Turn off debug symbols for the regular release build. These symbols add 300+MB to
      # Impala's binary size. Oddly enough, the -asserts build doesn't have a similar
      # problem.
      wrap ${THIS_DIR}/build-helper.sh ${HELPER_ARGS} \
        -build_dir "${LLVM_BUILD_DIR}" \
        -install_dir "${PROFILE_USE_INSTALL_DIR}" \
        -release \
        -g0 \
        -add_cflags "${PROFILE_USE_CFLAGS}" \
        -add_cxxflags "${PROFILE_USE_CFLAGS}" \
        -extra_cmake_args "${PROFILE_USE_EXTRA_CMAKE_ARGS}"

      wrap echo "######################## End PGO Build #3 ########################"
    )
  else
    # This is not PGO, so this is a single standard build. Nothing special is needed for
    # the compiler or flags.
    rm -rf "${THIS_DIR}/build-$PACKAGE_STRING"
    HELPER_ARGS+=" -build_dir ${THIS_DIR}/build-$PACKAGE_STRING"
    HELPER_ARGS+=" -install_dir ${LOCAL_INSTALL}"
    HELPER_ARGS+=" -add_cflags ${GCC_CFLAGS} -add_cxxflags ${GCC_CFLAGS}"
    if [[ "${PACKAGE_VERSION}" =~ "-asserts" ]]; then
      # Always have minimal debug info for the asserts build
      HELPER_ARGS+=" -asserts"
      HELPER_ARGS+=" -g1"
    elif [[ "$PACKAGE_VERSION" =~ "-debug" ]]; then
      HELPER_ARGS+=" -debug"
    else
      # Turn off debug symbols for the regular release build. These symbols add 300+MB to
      # Impala's binary size. Oddly enough, the -asserts build doesn't have a similar
      # problem.
      HELPER_ARGS+=" -release"
      HELPER_ARGS+=" -g0"
    fi

    wrap ${THIS_DIR}/build-helper.sh ${HELPER_ARGS}
  fi

  finalize_package_build $PACKAGE $PACKAGE_VERSION
fi
