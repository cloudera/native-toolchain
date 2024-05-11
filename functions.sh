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

# Prepend command with timestamp
alias ts="sed \"s;^;`date '+%D %T'` ;\""

# Pushd and popd print the directory stack by default. Silence this or produce more helpful
# output depending on debug mode.
function pushd() {
  if [[ $DEBUG -ne 0 ]]; then
    echo "Entering directory $1"
  fi
  command pushd $1 > /dev/null
}

function popd() {
  if [[ $DEBUG -ne 0 ]]; then
    echo "Returning to directory $(dirs -1)"
  fi
  command popd > /dev/null
}

# Downloads a given package from S3, arguments to this function are the package and
# package-filename and the target download folder
function download_dependency() {
  # S3 Base URL
  local S3_BASE_PREFIX="https://native-toolchain.s3.amazonaws.com/source"
  download_url "${S3_BASE_PREFIX}/${1}/${2}" "${3}/${2}"
}

# Downloads a URL (first arg) to a given location (second arg). If a file already exists
# at the location, the download will not be attempted.
function download_url() {
  local URL=$1
  local OUTPUT_PATH="${2-$(basename $URL)}"
  if [[ ! -f "$OUTPUT_PATH" ]]; then
    ARGS=(--progress=dot:giga)
    if [[ $DEBUG -eq 0 ]]; then
      ARGS+=(-q)
    fi
    if [[ -n "$OUTPUT_PATH" ]]; then
      ARGS+=(-O "$OUTPUT_PATH")
    fi
    ARGS+=("$URL")
    wget "${ARGS[@]}"
  fi
}

# Usage: clean_dir <directory path>
# Cleans the specified directory of non-versioned files.
function clean_dir() {
  local DIR=$1
  echo "Cleaning $DIR ..."
  # git clean fails on some versions when provided absolute path of current directory.
  pushd "$DIR"
  git clean -fdx .
  popd
}

# Checks if the existing build artifacts need to be removed and verifies
# that all required directories exist.
function prepare_build_dir() {
  if [ $CLEAN -eq 1 ]; then
    clean_dir "$SOURCE_DIR"
  fi

  # Destination directory for build
  export BUILD_DIR=$SOURCE_DIR/build
  mkdir -p "$BUILD_DIR"

  # Create a check directory containing a sentry file for each package
  mkdir -p $SOURCE_DIR/check
}

# Wraps the passed in command to either output it to a log file or tee the
# output to stdout and write it to a logfile.
function wrap() {
  if [[ $DEBUG -eq 0 ]]; then
    "$@" >> $BUILD_LOG 2>&1
  else
    "$@" 2>&1 | tee $BUILD_LOG
  fi
}

function prepare() {
  PACKAGE="$(basename $1)"; PACKAGE=`echo "${PACKAGE}" | awk '{print tolower($0)}'`
  local UPPER_PACKAGE=`echo "${PACKAGE}" | awk '{print toupper($0)}'`
  PACKAGE_VERSION_VAR="${UPPER_PACKAGE}_VERSION"
  # Replace potential - with _
  PACKAGE_VERSION_VAR="${PACKAGE_VERSION_VAR//-/_}"
  PACKAGE_VERSION="${!PACKAGE_VERSION_VAR}"

  # Regex to match patch level
  patch_regex="(.*)-p([[:digit:]]+)$"

  # Extract the patch level
  if [[ $PACKAGE_VERSION =~ $patch_regex ]]; then
    PATCH_LEVEL="${BASH_REMATCH[2]}"
    PATCH_VERSION="-p${PATCH_LEVEL}"
    PACKAGE_VERSION="${BASH_REMATCH[1]}"
  else
    PATCH_LEVEL=
    PATCH_VERSION=
  fi

  PACKAGE_STRING="$PACKAGE-$PACKAGE_VERSION"

  # Export these variables so that they are accessible to build scripts.
  export PACKAGE PACKAGE_VERSION PACKAGE_STRING PATCH_LEVEL PATCH_VERSION
}



# Build helper function that extracts a package archive, applies any patches,
# and sets the necessary environment variables that can be used to build.
# This is a wrapper around setup_extracted_package_build() that extracts
# the appropriate archive, then calls setup_extracted_package_build().
# If <archive file> is specified, extract that archive, otherwise attempt to
# find based on the package name and version.
# If <extracted archive dir> and <target dir> are both provided, assume that the
# archive unpacks to the first directory and move it to <target dir>.
# If PATCH_DIR is set, look in that directory for patches. Otherwise look in
# "<package name>-<package version>-patches"
# Usage: setup_package_build <package name> <package version> [<archive file>
#                            [<extracted archive dir> [<target dir>
#                            [<extract command>]]]]
function setup_package_build() {
  local PKG_NAME=$1
  local PKG_VERSION=$2
  local ARCHIVE=${3-}
  local EXTRACTED_DIR=${4-}
  local TARGET_DIR=${5-"$EXTRACTED_DIR"}

  echo "#######################################################################"
  echo "# Building: ${PKG_NAME}-${PKG_VERSION}${PATCH_VERSION}"

  cd $SOURCE_DIR/source/$PKG_NAME

  # Extract the sources
  if [ ! -z "$ARCHIVE" ]; then
    extract_archive $ARCHIVE
    if [ "$EXTRACTED_DIR" != "$TARGET_DIR" ]; then
      # Remove any existing directory
      rm -rf "$TARGET_DIR"
      mv "$EXTRACTED_DIR" "$TARGET_DIR"
    fi
    DIR=$TARGET_DIR
  elif [ -f ${PKG_NAME}-${PKG_VERSION}.tar.gz ]; then
    extract_archive ${PKG_NAME}-${PKG_VERSION}.tar.gz
    DIR=${PKG_NAME}-${PKG_VERSION}
  elif [ -f ${PKG_NAME}-${PKG_VERSION}.tgz ]; then
    extract_archive ${PKG_NAME}-${PKG_VERSION}.tgz
    DIR=${PKG_NAME}-${PKG_VERSION}
  elif [ -f ${PKG_NAME}-${PKG_VERSION}.src.tar.gz ]; then
    extract_archive ${PKG_NAME}-${PKG_VERSION}.src.tar.gz
    DIR=${PKG_NAME}-${PKG_VERSION}.src
  elif [ -f $PKG_NAME-src-${PKG_VERSION}.tar.gz ]; then
    extract_archive $PKG_NAME-src-${PKG_VERSION}.tar.gz
    DIR=$PKG_NAME-src-${PKG_VERSION}
  elif [ -f ${PKG_NAME}-${PKG_VERSION}.tar.xz ]; then
    extract_archive ${PKG_NAME}-${PKG_VERSION}.tar.xz
    DIR=${PKG_NAME}-${PKG_VERSION}
  elif [ -f ${PKG_NAME}-${PKG_VERSION}.xz ]; then
    extract_archive ${PKG_NAME}-${PKG_VERSION}.xz
    DIR=${PKG_NAME}-${PKG_VERSION}
  elif [ -f ${PKG_NAME}-${PKG_VERSION}.src.tar.xz ]; then
    extract_archive ${PKG_NAME}-${PKG_VERSION}.src.tar.xz
    DIR=${PKG_NAME}-${PKG_VERSION}.src
  elif [ -f $PKG_NAME-src-${PKG_VERSION}.tar.xz ]; then
    extract_archive $PKG_NAME-src-${PKG_VERSION}.tar.xz
    DIR=$PKG_NAME-src-${PKG_VERSION}
  elif [ -f ${PKG_NAME}-${PKG_VERSION}.zip ]; then
    extract_archive ${PKG_NAME}-${PKG_VERSION}.zip
    DIR=${PKG_NAME}-${PKG_VERSION}
  else
    DIR=${PKG_NAME}-${PKG_VERSION}
  fi


  # Depending how ugly things are packaged we might have directories that are different
  # from the archive name, looking at you boost
  RDIR="${DIR//-/_}"; RDIR="${RDIR//./_}"
  FINAL_DIR=
  if [ -d "$DIR" ]; then
    FINAL_DIR=$DIR
  elif [ -d "${RDIR}" ]; then
    FINAL_DIR=$RDIR
  else
    FINAL_DIR=$PKG_NAME
  fi

  setup_extracted_package_build $PKG_NAME $PKG_VERSION $FINAL_DIR
}

# Build helper function that applies any patches to an package and sets the
# necessary environment variables that can be used to build. This works
# on a package that has already been extracted from an archive. Most
# packages should look to use setup_package_build() rather than this function.
# If PATCH_DIR is set, look in that directory for patches. Otherwise look in
# "<package name>-<package version>-patches"
# Usage: setup_extracted_package_build <package name> <package version>
#                                      <extracted archive dir>
function setup_extracted_package_build() {
  local PKG_NAME=$1
  local PKG_VERSION=$2
  local DIR_NAME=$3

  LOCAL_INSTALL=$BUILD_DIR/${PKG_NAME}-${PKG_VERSION}${PATCH_VERSION}
  BUILD_LOG=$SOURCE_DIR/check/${PKG_NAME}-${PKG_VERSION}${PATCH_VERSION}.log

  # The specified directory is relative to the package source directory
  cd $SOURCE_DIR/source/$PKG_NAME
  pushd $DIR_NAME

  # Apply patches for this package
  if [[ -n "$PATCH_VERSION" ]]; then
    : ${PATCH_DIR="$SOURCE_DIR/source/${PKG_NAME}/${PKG_NAME}-${PKG_VERSION}-patches"}

    apply_patches ${PATCH_LEVEL} ${PATCH_DIR}

    # Once the patches are applied, move the directory to the correct name
    # with the patch level in the name
    popd
    if [[ -d $DIR_NAME$PATCH_VERSION ]]; then
      # Move away old directory from previous run
      i=0
      while true; do
        if [[ -d $DIR_NAME$PATCH_VERSION.bak$i ]]; then
          ((++i))
          continue
        fi
        mv $DIR_NAME$PATCH_VERSION $DIR_NAME$PATCH_VERSION.bak$i
        break
      done
    fi
    mv $DIR_NAME $DIR_NAME$PATCH_VERSION
    pushd $DIR_NAME$PATCH_VERSION
  fi
}

# Build helper function that packages the build result, creates symbolic links
# to the package's binaries, creates a check-point file to signal a successful
# build, and optionally cleans up the build directory to free space.
# Usage: finalize_package_build <package name> <package version>
function finalize_package_build() {
  local PKG_NAME=$1
  local PKG_VERSION=$2

  local PKG_BUILD_DIRNAME=${PKG_NAME}-${PKG_VERSION}${PATCH_VERSION}
  local PKG_BUILD_DIR="$BUILD_DIR/$PKG_BUILD_DIRNAME"

  if [[ $PKG_NAME != 'gcc' && $PKG_NAME != 'binutils' && $PKG_NAME != 'gdb' ]]; then
    pushd "$BUILD_DIR"
    # Add symlinks to required libraries.
    # Make sure that libstdc++ and libgcc are linked where they will be on the RPATH.
    # We need to use relative paths here to get relative symlinks.
    symlink_required_libs gcc-${GCC_VERSION}/lib64 "$PKG_BUILD_DIRNAME"
    popd
  fi

  # Build Package
  build_dist_package 2>&1 | tee -a $BUILD_LOG

  # For all binaries of the package symlink to bin
  if [[ -d "$PKG_BUILD_DIR"/bin ]]; then
    mkdir -p $BUILD_DIR/bin
    for p in `ls "$PKG_BUILD_DIR"/bin`; do
      ln -f -s "$PKG_BUILD_DIR"/bin/$p $BUILD_DIR/bin/$p
    done
  fi

  touch $SOURCE_DIR/check/${PKG_NAME}-${PKG_VERSION}${PATCH_VERSION}

  if [ $CLEAN_TMP_AFTER_BUILD -eq 1 ]; then
    # The current directory may be a build directory that we're about to remove.
    cd $SOURCE_DIR
    clean_dir "$SOURCE_DIR/source/${PKG_NAME}"
  fi
  echo "# Build Complete ${PKG_NAME}-${PKG_VERSION}${PATCH_VERSION}"
  echo "#######################################################################"
}


# Check if environment variables BUILD_ALL=0 and a variable of the
# name PACKAGE_NAME_VERSION is set indicating that this package needs
# to be build.
function needs_build_package() {

  # First check if the build_all variable is set or not
  : ${BUILD_ALL=1}

  if [ ! -f $SOURCE_DIR/check/${PACKAGE_STRING}${PATCH_VERSION} ] && [ $BUILD_ALL -eq 1 ]; then
    return 0
  fi

  local UPPER_PACKAGE=`echo "${PACKAGE}" | awk '{print toupper($0)}'`
  ENV_NAME="BUILD_${UPPER_PACKAGE//-/_}"
  ENV_NAME=${!ENV_NAME=0}

  if [ $BUILD_ALL -eq 0 ] && [ $ENV_NAME -eq 1 ]; then
    return 0 # Build package
  else
    return 1 # Dont build this package
  fi
}

# Check the package_name-version-patches directory and apply patches
# depending on patch-level. Patches must be prepared that they can be
# applied directly on the extracted source tree from within the source
# (-p2 / -p1).
# Usage: apply_patches <patch level> <directory with patches>
function apply_patches() {
  local PATCH_LEVEL=$1
  local PATCH_DIR=$2
  echo "Apply patches up to ${PATCH_LEVEL}"
  PATCH_NUM=1
  if [[ -d "$PATCH_DIR" ]]; then
    for p in `find -L "$PATCH_DIR" -type f | sort`; do
      echo "Applying patch ${PATCH_NUM}...${p}"
      set +e
      # Check if patch can be applied at -p2 first, then p1
      patch --verbose -p2 < $p >> $BUILD_LOG 2>&1
      RET_VAL=$?
      set -e
      if [[ $RET_VAL -ne 0 ]]; then
        patch --verbose -p1 < $p >> $BUILD_LOG 2>&1
      fi
      PATCH_NUM=$(($PATCH_NUM + 1))
      if [[ $PATCH_NUM -gt $PATCH_LEVEL ]]; then
        echo "All required patches applied."
        return 0
      fi
    done
  fi
  if [[ $PATCH_NUM -le $PATCH_LEVEL ]]; then
    echo "Expected to find at least $PATCH_LEVEL patches in directory $PATCH_DIR but" \
         "only found $(($PATCH_NUM - 1))"
    return 1
  fi
}


# Build a fake package
function build_fake_package() {
  prepare  $1

  if needs_build_package; then
    DESTDIR="${BUILD_DIR}/${PACKAGE_STRING}${PATCH_VERSION}"
    mkdir -p ${DESTDIR}
    echo "Package not built for $OSTYPE $OS_NAME $ARCH_NAME." >> ${DESTDIR}/README

    # Package and upload the fake dir
    build_dist_package
    touch $SOURCE_DIR/check/${PACKAGE_STRING}${PATCH_VERSION}
  fi
}

function upload_to_s3() {
  local FILENAME=$1
  local S3_LOCATION=$2

  # Upload to s3 can be flaky on certain platforms, so this retries a few times
  # to compensate.
  local NUM_RETRIES=10
  for ((i=1; i<=${NUM_RETRIES}; i++)); do
    echo "Uploading ${FILENAME} to ${S3_LOCATION} (attempt #${i})"
    if aws s3 cp --only-show-errors ${FILENAME} ${S3_LOCATION} ; then
      echo "Successfully uploaded ${FILENAME} to ${S3_LOCATION}"
      return 0;
    fi
    echo "Failed to upload ${FILENAME} to ${S3_LOCATION}"
  done
  return 1;
}

# Build the RPM or DEB package depending on the operating system.
# Depends on the LOCAL_INSTALL variable containing the target directory and the
# TOOLCHAIN_BUILD_ID variable containing a unique string.
#
# Depending on the variables PUBLISH_DEPENDENCIES_ARTIFACTORY and
# PUBLISH_DEPENDENCIES_S3 the package is also uploaded to a Maven repo as a binary
# package, or to the S3 buckets hosting native-toolchain, respectively.

function build_dist_package() {
  SOURCE_TYPE="dir"

  # Produce a tar.gz for the binary product for easier bootstrapping
  FULL_TAR_NAME="${PACKAGE_STRING}${PATCH_VERSION}-${COMPILER}"
  FULL_TAR_NAME+="-${COMPILER_VERSION}"

  # Add the toolchain git hash to the tarball so the compiled package can be traced
  # back to the set of build scripts/flags used to compile it.
  git rev-parse HEAD > \
    ${BUILD_DIR}/${PACKAGE_STRING}${PATCH_VERSION}/toolchain-build-hash.txt

  PACKAGE_FINAL_TGZ="${BUILD_DIR}/${FULL_TAR_NAME}.tar.gz"

  COMPRESS_CMD="gzip"
  if command -v pigz > /dev/null ; then
    COMPRESS_CMD="pigz"
  fi
  COMPRESS_OPTION="--use-compress-program=${COMPRESS_CMD}"
  tar cf ${PACKAGE_FINAL_TGZ}\
    ${COMPRESS_OPTION} \
    --directory=${BUILD_DIR} \
    ${PACKAGE_STRING}${PATCH_VERSION}

  # If desired break on failure to publish the artifact
  RET_VAL=true
  if [[ $FAIL_ON_PUBLISH -eq 1 ]]; then
    RET_VAL=false
  fi

  : ${PUBLISH_DEPENDENCIES_S3="$PUBLISH_DEPENDENCIES"}
  : ${PUBLISH_DEPENDENCIES_ARTIFACTORY="$PUBLISH_DEPENDENCIES"}

  # Package and upload the archive to the artifactory
  if [[ "PUBLISH_DEPENDENCIES_ARTIFACTORY" -eq "1" ]]; then
    mvn -B deploy:deploy-file -DgroupId=com.cloudera.toolchain\
      -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn\
      -DartifactId="${PACKAGE}"\
      -Dversion="${PACKAGE_VERSION}${PATCH_VERSION}-${COMPILER}-${COMPILER_VERSION}-${TOOLCHAIN_BUILD_ID}"\
      -Dfile="${PACKAGE_FINAL_TGZ}"\
      -Durl="http://maven.jenkins.cloudera.com:8081/artifactory/cdh-staging-local/"\
      -DrepositoryId=cdh.releases.repo -Dpackaging=tar.gz -Dclassifier=${BUILD_LABEL} || $RET_VAL
  fi

  if [[ "PUBLISH_DEPENDENCIES_S3" -eq "1" ]]; then
    local ARCH=$(uname -m)
    local PACKAGE_RELATIVE_URL="build/${TOOLCHAIN_BUILD_ID}/${PACKAGE}/${PACKAGE_VERSION}${PATCH_VERSION}-${COMPILER}-${COMPILER_VERSION}/${FULL_TAR_NAME}-${BUILD_LABEL}-${ARCH}.tar.gz"
    local PACKAGE_S3_DESTINATION="s3://${S3_BUCKET}/${PACKAGE_RELATIVE_URL}"
    upload_to_s3 ${PACKAGE_FINAL_TGZ} ${PACKAGE_S3_DESTINATION} || $RET_VAL
    # S3_MIRROR_BUCKET may be empty for experimental builds
    if [[ -n ${S3_MIRROR_BUCKET:-} ]]; then
      local PACKAGE_MIRROR_DESTINATION="s3://${S3_MIRROR_BUCKET}/${PACKAGE_RELATIVE_URL}"
      echo "Uploading to mirror:"
      upload_to_s3 ${PACKAGE_FINAL_TGZ} ${PACKAGE_MIRROR_DESTINATION} || $RET_VAL
    fi
  fi
}

# Given the assumption that all other build steps completed successfully, generate a meta
# package that pulls in all dependencies.
function build_meta_package() {
  NAME=$1
  shift
  PACKAGES=("${@}")
  SOURCE_TYPE="empty"

  set_target_package_type

  if [[ -z $TARGET ]]; then
    return 0
  fi

  DEPENDENCIES=""
  for dep in ${PACKAGES[@]}; do
    DEPENDENCIES="${DEPENDENCIES} -d ${dep}"
  done

  # Build the package
  fpm -f -p $BUILD_DIR --prefix $TOOLCHAIN_PREFIX -s $SOURCE_TYPE \
    ${DEPENDENCIES} -t $TARGET -n "${NAME}" \
    -v "${NAME}-${PLATFORM_VERSION}"
}

# Helper to extract archives of various types into current directory.
function extract_archive() {
  local ARCHIVE=$1
  case "$ARCHIVE" in
    *.tar.gz | *.tgz | *.parcel)
      tar xzf "$ARCHIVE"
      ;;
    *.xz)
      tar xJf "$ARCHIVE"
      ;;
    *.zip)
      unzip -qo "$ARCHIVE"
      ;;
    *)
      echo "Did not recognise archive extension: $ARCHIVE"
      return 1
      ;;
  esac
}

# Generate a unique build ID that includes a prefix of the git hash.
function generate_build_id() {
  local GIT_HASH=$(git rev-parse --short=10 HEAD)
  # Get Jenkins build number or a unique id if we're not in jenkins.
  local UNIQUE_ID=${BUILD_NUMBER:-$(cat /proc/sys/kernel/random/uuid)}
  echo "${UNIQUE_ID}-${GIT_HASH}"
}

# Adds the toolchain gcc library directory to LD_LIBRARY_PATH if the toolchain gcc
# version is newer than the system gcc version.
#
# This should be called by the build of the various components - cmake, flatbuffers,
# kudu, etc - that invoke binaries they built during their builds. The dynamic linker
# needs to be able to find the correct versions of libgcc.so, libstdc++.so, etc. We
# usually rely on setting the rpath in the binary and symlinking those libraries, but
# in this case the libraries are not symlinked until after the component build
# completes, so the dynamic linker needs LD_LIBRARY_PATH to locate them.
#
# GCC's libraries are backwards compatible, so we need the version check to pick
# the library version that will work for both toolchain binaries and any system binaries
# that are invoked during builds.
function add_gcc_to_ld_library_path() {
  local gcc_version=$(gcc -dumpversion)
  local older_version=$(echo -e "$gcc_version\n$SYSTEM_GCC_VERSION" |
                        sort --version-sort | head -n1)
  if [[ "$older_version" == "$SYSTEM_GCC_VERSION" ]]
  then
    if [[ -z "${LD_LIBRARY_PATH:-}" ]]; then
      LD_LIBRARY_PATH=""
    else
      LD_LIBRARY_PATH=":${LD_LIBRARY_PATH}"
    fi
    export LD_LIBRARY_PATH="$BUILD_DIR/gcc-$GCC_VERSION/lib64${LD_LIBRARY_PATH}"
  fi
}

# Wrap the given compiler in a script that executes ccache. Return the
# wrapped script.
#
# This function is a no-op if the given compiler is already ccache.
function setup_ccache() {
  local ORIG_COMPILER="$1"
  if ! which ccache &> /dev/null; then
    >&2 echo "USE_CCACHE was enabled but ccache is not in PATH"
    exit 1
  fi
  # We're already a symlink to ccache, nothing to do here.
  if readlink $ORIG_COMPILER|grep -q ccache; then
    return 0
  fi

  mkdir -p $CCACHE_DIR
  local TEMPDIR=$(mktemp -d --suffix="-impala-toolchain")
  local RET=$TEMPDIR/$(basename $ORIG_COMPILER)
  # Setting CC='ccache gcc' causes some programs to try to execute `ccache gcc`,
  # which fails. Since we set our CC variable, we can't rely on PATH ordering
  # to tell ccache about our compiler, so we create our own CC wrapper which is
  # then added to the PATH by the caller.
  printf "#!/bin/sh\nexec ccache $ORIG_COMPILER "'"$@"\n' > "$RET"
  chmod 770 "$RET"
  echo $RET
}

# Download ccache into $CCACHE_DIR from the native-toolchain bucket. If multiple
# processes/containers call this function only the first process to acquire a lock
# will perform the download. Failing to download a cache tarball is not considered
# fatal. After downloading ccache from s3, the statistics are zero-ed out.
function download_ccache() {
  local WAIT_SECONDS=600
  local LOCK=$CCACHE_DIR/ccache.lock
  local TAR=ccache.tar
  local S3_URL="https://native-toolchain.s3.amazonaws.com/ccache/$TAR"
  mkdir -p $CCACHE_DIR
  (
    flock -w $WAIT_SECONDS 200
    if [[ -f "$CCACHE_DIR/ccache.done" ]]; then
      # Nothing to do here. Already downloaded in another container.
      return 0
    fi
    if ! download_url "$S3_URL"; then
      >&2 echo "Unable to download cache. Will fall back to an empty ccache directory"
      touch $CCACHE_DIR/ccache.done
      return 0
    fi
    tar -C $CCACHE_DIR -xf $TAR --strip 1
    touch $CCACHE_DIR/ccache.done
    rm -f $TAR
    ccache -z
  ) 200> "$LOCK"
  rm -f "$LOCK"
}

# Upload a tarball containing all files in $CCACHE_DIR to $S3_BUCKET/ccache/ccache.tar
function upload_ccache() {
  local S3_PREFIX="s3://${S3_BUCKET}/ccache"
  local EXPIRES="$(date -d '+3 months' --utc +'%Y-%m-%dT%H:%M:%SZ')"
  local EXPECTED_SIZE=$((1024*1024*1024 * 12))
  local REGION="us-west-1"

  # We do not compress here to speed up this operation which happens as part of the critical
  # path, instead, we use CCACHE_COMPRESS=1
  tar --exclude="ccache.done" \
    --exclude="ccache.conf" \
    -C $(dirname $CCACHE_DIR) \
    -cf - $(basename $CCACHE_DIR) \
    | aws s3 cp \
        --expires "$EXPIRES" \
        --expected-size $EXPECTED_SIZE \
        --region=$REGION - $S3_PREFIX/ccache.tar
  ccache -s | aws s3 cp --region="$REGION" - "$S3_PREFIX/stats.$TOOLCHAIN_BUILD_ID"
}

# Usage: symlink_required_libs <src build dir> <dst build dir>
# Finds all shared objects under the src build dir required by shared objects or
# executables in the dst build dir and add symlinks to the required libraries in
# the ../lib/ directory relative to the binary that requires the library, where
# it will on the rpath for the binary. Both paths provided must be relative paths.
# The symlink constructed will be a relative symlink, so will work when the build
# directory is placed in a different location.
function symlink_required_libs() {
  local src_dir=$1
  local dst_dir=$2
  local src_libs=$(find "$src_dir" -name '*.so*')

  local executables=$(find "$dst_dir" -perm '/u=x,g=x,o=x' -type f)
  local shared_libs=$(find "$dst_dir" -name '*.so*')

  local file
  for file in $executables $shared_libs; do
    # Get the required libraries. If this is not a binary executable, this command fails
    # and we can skip over the file.
    if ! local required_libs=$(objdump -p "$file" 2>/dev/null | grep NEEDED | awk '{print $2}')
    then
      continue
    fi

    # Check for matches using a naive N^2 algorithm with a basic fast-path optimization
    local required_lib
    local src_lib
    for required_lib in $required_libs; do
      # Calculate the lib directory for the $dst_dir (i.e. the directory that we would put
      # the symlink in if we decided we needed it)
      local dst_lib_dir=$(calc_dst_lib_dir $(dirname $file))

      # Fast path: If the required library is already in the $dst_lib_dir, then we can
      # bail out early.
      #
      # This can happen if we already symlinked the library into $dst_lib_dir or it can
      # happen if a shared library has a dependency on another shared library in the
      # same directory (i.e. libfoo_a.so depends on libfoo_b.so).
      #
      # This fast path makes a large difference for Abseil, as it has many shared
      # libraries that depend on each other.
      if [[ -f "$dst_lib_dir/$required_lib" ]]; then
        # If the $dst_lib_dir already has an entry for the required library, then we can
        # bail out early.
        continue
      fi

      # Slow path: Look through the list of source libraries to find a match
      for src_lib in $src_libs; do
        if [[ "$(basename $src_lib)" = "$required_lib" ]]; then
          # We found a dependency.
          symlink_lib "$src_lib" "$file"
          break
        fi
      done
    done
  done
}

# Usage: calc_relpath <src> <dst>
# Calculate and print to stdout the relative path from <src> to <dst>.
function calc_relpath() {
  local src=$1
  local dst=$2
  realpath --relative-to="$dst" "$src"
}

function calc_dst_lib_dir() {
  local dst_dir=$1
  if [[ "$(basename "$dst_dir")" == "lib" ]]; then
    # Don't insert extraneous ../lib
    echo "$dst_dir"
  else
    echo "$dst_dir/../lib"
  fi
}

# Usage: symlink_lib <src lib> <binary>
# Create a relative symlink to <src lib> where it will on the rpath of <binary>.
# <src lib> and <binary> must be relative paths from the current directory.
function symlink_lib() {
  local src_lib=$1
  local binary=$2
  local binary_dir="$(dirname "$binary")"

  # The lib/ subfolder is on the rpath of all binaries. Add a symlink there.
  local dst_lib_dir=$(calc_dst_lib_dir "$binary_dir")
  local src_lib_rel_path=$(calc_relpath "$src_lib" "$dst_lib_dir")

  # Add the symlink if not already present.
  mkdir -p "$dst_lib_dir"
  pushd "$dst_lib_dir"
  local lib_name="$(basename "$src_lib")"
  # Create a symlink if the library (or a symlink to it) is not present.
  [[ -e "$lib_name" ]] || ln -s "${src_lib_rel_path}" "$lib_name"
  if [[ ! -e "$lib_name" ]]; then
    echo "Broken symlink $lib_name in $(pwd)"
    return 1
  fi
  popd
}

# Print a message to standard error and exit with a non-zero status.
function die() {
  printf '%s\n' "$1" >&2
  exit 1
}
