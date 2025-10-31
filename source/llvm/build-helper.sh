#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

set -euo pipefail

SOURCE_DIR=
SOURCE_DIR_TYPE=
BUILD_DIR=
INSTALL_DIR=
EXTRA_CMAKE_ARGS=
LLVM_BUILD_TYPE=
LLVM_ENABLE_PROJECTS="clang;clang-tools-extra;compiler-rt;lld"
CFLAGS="${CFLAGS-}"
CXXFLAGS="${CXXFLAGS-}"
LDFLAGS="${LDFLAGS-}"
CC="${CC-}"
CXX="${CXX-}"
ARCH_NAME="${ARCH_NAME:-$(uname -p)}"

while [ -n "$*" ]
do
  case "$1" in
    -source_dir)
      SOURCE_DIR="${2-}"
      if [[ ! -d "$SOURCE_DIR" ]]; then
        echo "-source_dir does not exist: $SOURCE_DIR"
        exit 1
      fi
      shift;
      ;;
    -source_dir_type)
      # Either "unified" or "legacy"
      SOURCE_DIR_TYPE="${2-}"
      if [[ ${SOURCE_DIR_TYPE} != "unified" && ${SOURCE_DIR_TYPE} != "legacy" ]]; then
        echo "Invalid -source_dir_type, must be 'unified' or 'legacy': ${SOURCE_DIR_TYPE}"
        exit 1
      fi
      shift;
      ;;
    -build_dir)
      BUILD_DIR="${2-}"
      shift;
      ;;
    -install_dir)
      INSTALL_DIR="${2-}"
      shift;
      ;;
    -release)
      LLVM_BUILD_TYPE=Release
      ;;
    -relwithdebinfo)
      LLVM_BUILD_TYPE=RelWithDebInfo
      ;;
    -debug)
      LLVM_BUILD_TYPE=Debug
      ;;
    -asserts)
      LLVM_BUILD_TYPE=Release
      EXTRA_CMAKE_ARGS+=" -DLLVM_ENABLE_ASSERTIONS=true"
      ;;
    -g0)
      CFLAGS="${CFLAGS} -g0"
      CXXFLAGS="${CXXFLAGS} -g0"
      ;;
    -g1)
      CFLAGS="${CFLAGS} -g1"
      CXXFLAGS="${CXXFLAGS} -g1"
      ;;
    -g)
      CFLAGS="${CFLAGS} -g"
      CXXFLAGS="${CXXFLAGS} -g"
      ;;
    -cc_override)
      # Override CC
      CC="${2-}"
      if ! command -v "${CC}" ; then
        echo "Invalid -cc_override: ${CC}"
        exit 1
      fi
      shift;
      ;;
    -cxx_override)
      # Override CXX
      CXX="${2-}"
      if ! command -v "${CXX}" ; then
        echo "Invalid -cxx_override: ${CXX}"
        exit 1
      fi
      shift;
      ;;
    -ld_override)
      LD_OVERRIDE="${2-}"
      if ! command -v "${LD_OVERRIDE}" ; then
        echo "Invalid -ld_override: ${LD_OVERRIDE}"
        exit 1
      fi
      EXTRA_CMAKE_ARGS+=" -DLLVM_USE_LINKER=${LD_OVERRIDE}"
      shift;
      ;;
    -add_cflags)
      CFLAGS="${CFLAGS} ${2-}"
      shift;
      ;;
    -add_cxxflags)
      CXXFLAGS="${CXXFLAGS} ${2-}"
      shift;
      ;;
    -add_ldflags)
      LDFLAGS="${LDFLAGS} ${2-}"
      shift;
      ;;
    -extra_cmake_args)
      EXTRA_CMAKE_ARGS+=" ${2-}"
      shift;
      ;;
    -llvm_enable_projects)
      LLVM_ENABLE_PROJECTS="${2-}"
      shift;
      ;;
    -help|*)
      echo "build-helper.sh - Builds LLVM with specific options."
      echo "TODO: Add information about each option"
      exit 1
      ;;
  esac
  shift;
done

if [[ -z "${LLVM_BUILD_TYPE}" ]]; then
  echo "Must specify -release, -debug, or -asserts"
  exit 1
fi

if [[ -n "${SOURCE_DIR}" ]]; then
  # Turn into an absolute path if not already
  if [[ "${SOURCE_DIR}" != /* ]]; then
    SOURCE_DIR="$(pwd)/${SOURCE_DIR}"
  fi
  echo "SOURCE_DIR: ${SOURCE_DIR}"
else
  echo "Must specify -source_dir"
  exit 1
fi

if [[ -z "${SOURCE_DIR_TYPE}" ]]; then
  echo "Must specify -source_dir_type"
  exit 1
fi

if [[ -n "${BUILD_DIR}" ]]; then
  # Turn into an absolute path if not already
  if [[ "${BUILD_DIR}" != /* ]]; then
    BUILD_DIR="$(pwd)/${BUILD_DIR}"
  fi
  echo "BUILD_DIR: $BUILD_DIR"
else
  echo "Must specify -build_dir"
  exit 1
fi

if [[ -n "${INSTALL_DIR}" ]]; then
  # Turn into an absolute path if not already
  if [[ "${INSTALL_DIR}" != /* ]]; then
    INSTALL_DIR="$(pwd)/${INSTALL_DIR}"
  fi
  echo "INSTALL_DIR: $INSTALL_DIR"
else
  echo "Must specify -install_dir"
fi

if [[ -n "${CC}" ]]; then
  echo "CC: ${CC}"
  export CC
else
  echo "CC unspecified"
fi
if [[ -n "${CXX}" ]]; then
  echo "CXX: ${CXX}"
  export CXX
else
  echo "CXX unspecified"
fi
if [[ -n "${CXXFLAGS}" ]]; then
  echo "CXXFLAGS: ${CXXFLAGS}"
  export CXXFLAGS
else
  echo "CXXFLAGS unspecified"
fi
if [[ -n "${CFLAGS}" ]]; then
  echo "CFLAGS: ${CFLAGS}"
  export CFLAGS
else
  echo "CFLAGS unspecified"
fi
if [[ -n "${LDFLAGS}" ]]; then
  echo "LDFLAGS: $LDFLAGS"
  export LDFLAGS
else
  echo "LDFLAGS unspecified"
fi

# We rely on ninja to limit link parallelism
if ! command -v ninja ; then
  echo "The 'ninja' build tool must be on the PATH"
  exit 1
fi

# LLVM needs python 3 for building
if ! command -v python3 ; then
  echo "The build for LLVM requires python3 on the PATH"
  exit 1
fi

if [[ "$ARCH_NAME" == "ppc64le" ]]; then
  LLVM_BUILD_TARGET+="PowerPC"
elif [[ "$ARCH_NAME" == "aarch64" ]]; then
  LLVM_BUILD_TARGET+="AArch64"
else
  LLVM_BUILD_TARGET+="X86"
fi

# Disable some builds we don't care about.
# TODO: This could be adjusted based on the LLVM version
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
  LLVM_INCLUDE_DOCS \
  LLVM_INCLUDE_EXAMPLES \
  LLVM_INCLUDE_TESTS \
  LLVM_INCLUDE_UTILS \
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

if [[ "${SOURCE_DIR_TYPE}" == "legacy" ]]; then
  LLVM_DIR="${SOURCE_DIR}"
else
  # SOURCE_DIR_TYPE==unified
  LLVM_DIR="${SOURCE_DIR}/llvm"
  EXTRA_CMAKE_ARGS+=" -DLLVM_ENABLE_PROJECTS=$LLVM_ENABLE_PROJECTS"
fi

mkdir -p ${BUILD_DIR}
pushd ${BUILD_DIR}

cmake ${LLVM_DIR} \
  -DCMAKE_BUILD_TYPE=${LLVM_BUILD_TYPE} \
  -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
  -GNinja \
  -DLLVM_TARGETS_TO_BUILD=$LLVM_BUILD_TARGET \
  -DLLVM_ENABLE_RTTI=ON \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_PARALLEL_COMPILE_JOBS=${BUILD_THREADS:-4} \
  -DLLVM_PARALLEL_LINK_JOBS=4 \
  -DCOMPILER_RT_SANITIZERS_TO_BUILD="tsan;asan" \
  ${EXTRA_CMAKE_ARGS}

# Ninja's -l option behaves like make's --load-average option
ninja -v -j${BUILD_THREADS:-4} -l${BUILD_THREADS:-4} install

popd

function strip_if_possible() {
  filename=$1
  if [[ "$(file -bi $filename)" = application/x-@(executable|sharedlib|archive)* ]]
  then
    strip -gx "$filename"
  fi
}

for binary in $(find ${INSTALL_DIR}/bin -type f); do
  strip_if_possible $binary
done

for binary in $(find ${INSTALL_DIR}/lib -iname "libclang*" -o -name "libLTO*"); do
  strip_if_possible $binary
done
