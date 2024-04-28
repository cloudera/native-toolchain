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

# Builds LLVM 3.7 and later from source tarballs.

set -eu
set -o pipefail

function build_llvm() {
  # Cleanup possible leftovers
  rm -Rf "$THIS_DIR/${PACKAGE_STRING}.src"
  rm -Rf "$THIS_DIR/build-${PACKAGE_STRING}"

  # The llvm source is composed of multiple archives, some of which are optional.
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

  # Patches are based on source version. Pass to setup_extracted_package_build function
  # with this var.
  PATCH_DIR=${THIS_DIR}/llvm-${SOURCE_VERSION}-patches

  setup_extracted_package_build $PACKAGE $PACKAGE_VERSION $TARGET_DIR

  if [[ "$OSTYPE" == "darwin"* ]]; then
    export CXX=
    export CC=
    export CXXFLAGS=
    export LDFLAGS=
  fi

  mkdir -p ${THIS_DIR}/build-$PACKAGE_STRING
  pushd ${THIS_DIR}/build-$PACKAGE_STRING
  local EXTRA_CMAKE_ARGS=
  local LLVM_BUILD_TYPE=Release
  if [[ "$PACKAGE_VERSION" =~ "-asserts" ]]; then
    LLVM_BUILD_TYPE=Release
    EXTRA_CMAKE_ARGS+=" -DLLVM_ENABLE_ASSERTIONS=true"
    # Always have minimal debug info for the asserts build
    export CXXFLAGS="${CXXFLAGS} -g1"
  elif [[ "$PACKAGE_VERSION" =~ "-debug" ]]; then
    LLVM_BUILD_TYPE=Debug
  else
    # Turn off debug symbols for the regular release build. These symbols add 300+MB to
    # Impala's binary size. Oddly enough, the -asserts build doesn't have a similar
    # problem.
    export CXXFLAGS="${CXXFLAGS} -g0"
  fi

  if [[ "$ARCH_NAME" == "ppc64le" ]]; then
    LLVM_BUILD_TARGET+="PowerPC"
  elif [[ "$ARCH_NAME" == "aarch64" ]]; then
    LLVM_BUILD_TARGET+="AArch64"
  else
    LLVM_BUILD_TARGET+="X86"
  fi

  # Disable some builds we don't care about.
  for arg in \
      CLANG_ENABLE_ARCMT \
      CLANG_TOOL_ARCMT_TEST_BUILD \
      CLANG_TOOL_C_ARCMT_TEST_BUILD \
      CLANG_TOOL_C_INDEX_TEST_BUILD \
      CLANG_TOOL_CLANG_CHECK_BUILD \
      CLANG_TOOL_CLANG_DIFF_BUILD \
      CLANG_TOOL_CLANG_FORMAT_VS_BUILD \
      CLANG_TOOL_CLANG_FUZZER_BUILD \
      CLANG_TOOL_CLANG_IMPORT_TEST_BUILD \
      CLANG_TOOL_CLANG_OFFLOAD_BUNDLER_BUILD \
      CLANG_TOOL_CLANG_REFACTOR_BUILD \
      CLANG_TOOL_CLANG_RENAME_BUILD \
      CLANG_TOOL_DIAGTOOL_BUILD \
      COMPILER_RT_BUILD_LIBFUZZER \
      LLVM_BUILD_BENCHMARKS \
      LLVM_ENABLE_OCAMLDOC \
      LLVM_INCLUDE_BENCHMARKS \
      LLVM_INCLUDE_GO_TESTS \
      LLVM_POLLY_BUILD \
      LLVM_TOOL_BUGPOINT_BUILD \
      LLVM_TOOL_BUGPOINT_PASSES_BUILD \
      LLVM_TOOL_DSYMUTIL_BUILD \
      LLVM_TOOL_LLI_BUILD \
      LLVM_TOOL_LLVM_AS_FUZZER_BUILD \
      LLVM_TOOL_LLVM_BCANALYZER_BUILD \
      LLVM_TOOL_LLVM_CAT_BUILD \
      LLVM_TOOL_LLVM_CFI_VERIFY_BUILD \
      LLVM_TOOL_LLVM_C_TEST_BUILD \
      LLVM_TOOL_LLVM_CVTRES_BUILD \
      LLVM_TOOL_LLVM_CXXDUMP_BUILD \
      LLVM_TOOL_LLVM_CXXFILT_BUILD \
      LLVM_TOOL_LLVM_DIFF_BUILD \
      LLVM_TOOL_LLVM_DIS_BUILD \
      LLVM_TOOL_LLVM_DWP_BUILD \
      LLVM_TOOL_LLVM_EXTRACT_BUILD \
      LLVM_TOOL_LLVM_GO_BUILD \
      LLVM_TOOL_LLVM_ISEL_FUZZER_BUILD \
      LLVM_TOOL_LLVM_JITLISTENER_BUILD \
      LLVM_TOOL_LLVM_MC_ASSEMBLE_FUZZER_BUILD \
      LLVM_TOOL_LLVM_MC_BUILD \
      LLVM_TOOL_LLVM_MC_DISASSEMBLE_FUZZER_BUILD \
      LLVM_TOOL_LLVM_MODEXTRACT_BUILD \
      LLVM_TOOL_LLVM_MT_BUILD \
      LLVM_TOOL_LLVM_NM_BUILD \
      LLVM_TOOL_LLVM_OBJCOPY_BUILD \
      LLVM_TOOL_LLVM_OBJDUMP_BUILD \
      LLVM_TOOL_LLVM_OPT_FUZZER_BUILD \
      LLVM_TOOL_LLVM_OPT_REPORT_BUILD \
      LLVM_TOOL_LLVM_PDBUTIL_BUILD \
      LLVM_TOOL_LLVM_PROFDATA_BUILD \
      LLVM_TOOL_LLVM_RC_BUILD \
      LLVM_TOOL_LLVM_READOBJ_BUILD \
      LLVM_TOOL_LLVM_RTDYLD_BUILD \
      LLVM_TOOL_LLVM_SHLIB_BUILD \
      LLVM_TOOL_LLVM_SIZE_BUILD \
      LLVM_TOOL_LLVM_SPECIAL_CASE_LIST_FUZZER_BUILD \
      LLVM_TOOL_LLVM_SPLIT_BUILD \
      LLVM_TOOL_LLVM_STRESS_BUILD \
      LLVM_TOOL_LLVM_STRINGS_BUILD \
      LLVM_TOOL_OBJ2YAML_BUILD \
      LLVM_TOOL_OPT_VIEWER_BUILD \
      LLVM_TOOL_VERIFY_USELISTORDER_BUILD \
      LLVM_TOOL_XCODE_TOOLCHAIN_BUILD \
      LLVM_TOOL_YAML2OBJ_BUILD \
      ; do
    EXTRA_CMAKE_ARGS+=" -D${arg}=OFF"
  done

  # Invoke CMake with the correct configuration
  wrap cmake ${THIS_DIR}/$PACKAGE_STRING.src${PATCH_VERSION} \
      -DCMAKE_BUILD_TYPE=${LLVM_BUILD_TYPE} \
      -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL \
      -DLLVM_TARGETS_TO_BUILD=$LLVM_BUILD_TARGET \
      -DLLVM_ENABLE_RTTI=ON \
      -DLLVM_ENABLE_TERMINFO=OFF \
      -DLLVM_INCLUDE_DOCS=OFF \
      -DLLVM_INCLUDE_EXAMPLES=OFF \
      -DLLVM_INCLUDE_TESTS=OFF \
      -DLLVM_PARALLEL_COMPILE_JOBS=${BUILD_THREADS:-4} \
      -DLLVM_PARALLEL_LINK_JOBS=${BUILD_THREADS:-4} \
      ${EXTRA_CMAKE_ARGS}

  wrap make VERBOSE=1 -j${BUILD_THREADS:-4} --load-average=${BUILD_THREADS:-4} install
  popd

  pushd ${THIS_DIR}/build-$PACKAGE_STRING/tools/clang
  wrap make VERBOSE=1 -j${BUILD_THREADS:-4} --load-average=${BUILD_THREADS:-4} install
  popd

  function strip_if_possible() {
    filename=$1
    if [[ "$(file -bi $filename)" = application/x-@(executable|sharedlib|archive)* ]]
    then
      strip -gx "$filename"
    fi
  }

  for binary in $(find ${LOCAL_INSTALL}/bin -type f); do
    strip_if_possible $binary
  done

  for binary in $(find ${LOCAL_INSTALL}/lib -iname "libclang*" -o -name "libLTO*"); do
    strip_if_possible $binary
  done

  finalize_package_build $PACKAGE $PACKAGE_VERSION
}
