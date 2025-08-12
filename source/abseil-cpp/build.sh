#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true

ts() { date +"%Y-%m-%dT%H:%M:%S%z"; }
log() { printf "[%s] %s\n" "$(ts)" "$*" >&2; }
trap 'log "ERROR at ${BASH_SOURCE[0]}:${BASH_LINENO[0]}: ${BASH_COMMAND}"' ERR

: "${SOURCE_DIR:?SOURCE_DIR must be set}"
source "${SOURCE_DIR}/functions.sh"

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
prepare "${THIS_DIR}"
cd "${THIS_DIR}"

ABSEIL_CPP_GITHUB_URL="${ABSEIL_CPP_GITHUB_URL:-https://github.com/abseil/abseil-cpp.git}"
ABSEIL_CPP_MIRROR_URL="${ABSEIL_CPP_MIRROR_URL:-}"
ABSEIL_CPP_SOURCE_DIR="abseil-cpp-${PACKAGE_VERSION:?PACKAGE_VERSION not set}"

if [[ -z "${BUILD_THREADS:-}" ]]; then
  if command -v nproc >/dev/null 2>&1; then BUILD_THREADS="$(nproc)"
  elif command -v sysctl >/dev/null 2>&1; then BUILD_THREADS="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
  else BUILD_THREADS=4; fi
fi

if command -v ccache >/dev/null 2>&1; then
  export CC="${CC:-ccache gcc}"
  export CXX="${CXX:-ccache g++}"
fi

retry() { local -r m=3; local -i n=0; local d=2; until "$@"; do n=$((n+1)); (( n>=m ))&&return 1; sleep "$d"; d=$((d*2)); done; }

clone_repo() { retry git clone --depth 1 "$1" "$2"; }
checkout_rev() {
  local rev="$1"
  if git rev-parse --verify --quiet "${rev}^{object}" >/dev/null; then
    git -c advice.detachedHead=false checkout --quiet "${rev}"
  else
    retry git fetch --depth 1 origin "${rev}"
    git -c advice.detachedHead=false checkout --quiet "${rev}"
  fi
}

if [[ ! -d "${ABSEIL_CPP_SOURCE_DIR}" ]]; then
  if [[ -n "${ABSEIL_CPP_MIRROR_URL}" ]]; then
    clone_repo "${ABSEIL_CPP_MIRROR_URL}" "${ABSEIL_CPP_SOURCE_DIR}" || clone_repo "${ABSEIL_CPP_GITHUB_URL}" "${ABSEIL_CPP_SOURCE_DIR}"
  else
    clone_repo "${ABSEIL_CPP_GITHUB_URL}" "${ABSEIL_CPP_SOURCE_DIR}"
  fi
  pushd "${ABSEIL_CPP_SOURCE_DIR}" >/dev/null
  checkout_rev "${PACKAGE_VERSION}"
  popd >/dev/null
else
  pushd "${ABSEIL_CPP_SOURCE_DIR}" >/dev/null
  checkout_rev "${PACKAGE_VERSION}"
  popd >/dev/null
fi

if ! needs_build_package; then
  log "No build needed for ${PACKAGE:-abseil-cpp} ${PACKAGE_VERSION}"
  exit 0
fi

setup_package_build "${PACKAGE:?PACKAGE not set}" "${PACKAGE_VERSION}"

rm -rf superbuild && mkdir superbuild
cat > superbuild/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.20)
project(absl_superbuild)
include(ExternalProject)
if(NOT DEFINED ENV{LOCAL_INSTALL})
  message(FATAL_ERROR "LOCAL_INSTALL env not set")
endif()
set(PREFIX $ENV{LOCAL_INSTALL})
set(SRC_DIR ${CMAKE_SOURCE_DIR}/../${ABSEIL_CPP_SOURCE_DIR})
if(NOT EXISTS "${SRC_DIR}/CMakeLists.txt")
  message(FATAL_ERROR "Source dir not found: ${SRC_DIR}")
endif()

set(COMMON_ARGS
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_INSTALL_PREFIX=${PREFIX}
  -DABSL_ENABLE_INSTALL=ON
  -DABSL_BUILD_TESTING=OFF
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DABSL_PROPAGATE_CXX_STD=ON
  -DCMAKE_INSTALL_RPATH=${PREFIX}/lib
  -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON
)

ExternalProject_Add(absl_static
  SOURCE_DIR "${SRC_DIR}"
  DOWNLOAD_COMMAND ""
  CMAKE_ARGS ${COMMON_ARGS} -DBUILD_SHARED_LIBS=OFF
  BUILD_COMMAND ${CMAKE_COMMAND} --build . -j $ENV{BUILD_THREADS}
  INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install -j $ENV{BUILD_THREADS}
)

ExternalProject_Add(absl_shared
  SOURCE_DIR "${SRC_DIR}"
  DOWNLOAD_COMMAND ""
  CMAKE_ARGS ${COMMON_ARGS} -DBUILD_SHARED_LIBS=ON
  BUILD_COMMAND ${CMAKE_COMMAND} --build . -j $ENV{BUILD_THREADS}
  INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install -j $ENV{BUILD_THREADS}
)

add_custom_target(install_all ALL DEPENDS absl_static absl_shared)
EOF

pushd superbuild >/dev/null
if command -v ninja >/dev/null 2>&1; then
  wrap cmake -G Ninja -DABSEIL_CPP_SOURCE_DIR="${ABSEIL_CPP_SOURCE_DIR}" .
  wrap ninja -j"${BUILD_THREADS}"
else
  wrap cmake -DABSEIL_CPP_SOURCE_DIR="${ABSEIL_CPP_SOURCE_DIR}" .
  wrap make -j"${BUILD_THREADS}"
fi
popd >/dev/null

finalize_package_build "${PACKAGE}" "${PACKAGE_VERSION}"
log "Completed ${PACKAGE} ${PACKAGE_VERSION}"
