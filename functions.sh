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
  S3_BASE_PREFIX="https://native-toolchain.s3.amazonaws.com/source"
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
# This is a wrapper around setup_extracked_package_build() that extracts
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

  # Build Package
  build_dist_package 2>&1 | tee -a $BUILD_LOG

  # For all binaries of the package symlink to bin
  if [[ -d $BUILD_DIR/${PKG_NAME}-${PKG_VERSION}${PATCH_VERSION}/bin ]]; then
    mkdir -p $BUILD_DIR/bin
    for p in `ls $BUILD_DIR/${PKG_NAME}-${PKG_VERSION}${PATCH_VERSION}/bin`; do
      ln -f -s $BUILD_DIR/${PKG_NAME}-${PKG_VERSION}${PATCH_VERSION}/bin/$p \
          $BUILD_DIR/bin/$p
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
    echo "Package not built for $OSTYPE $RELEASE_NAME $ARCH_NAME." >> ${DESTDIR}/README

    # Package and upload the fake dir
    build_dist_package
    touch $SOURCE_DIR/check/${PACKAGE_STRING}${PATCH_VERSION}
  fi
}

# Build the RPM or DEB package depending on the operating system.
# Depends on the LOCAL_INSTALL variable containing the target directory and the
# TOOLCHAIN_BUILD_ID variable containing a unique string.
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

  tar zcf ${PACKAGE_FINAL_TGZ}\
    --directory=${BUILD_DIR} \
    ${PACKAGE_STRING}${PATCH_VERSION}

  # If desired break on failure to publish the artifact
  RET_VAL=true
  if [[ $FAIL_ON_PUBLISH -eq 1 ]]; then
    RET_VAL=false
  fi

  # Package and upload the archive to the artifactory
  if [[ "PUBLISH_DEPENDENCIES" -eq "1" ]]; then
    mvn -B deploy:deploy-file -DgroupId=com.cloudera.toolchain\
      -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn\
      -DartifactId="${PACKAGE}"\
      -Dversion="${PACKAGE_VERSION}${PATCH_VERSION}-${COMPILER}-${COMPILER_VERSION}-${TOOLCHAIN_BUILD_ID}"\
      -Dfile="${PACKAGE_FINAL_TGZ}"\
      -Durl="http://maven.jenkins.cloudera.com:8081/artifactory/cdh-staging-local/"\
      -DrepositoryId=cdh.releases.repo -Dpackaging=tar.gz -Dclassifier=${BUILD_LABEL} || $RET_VAL

    PACKAGE_S3_DESTINATION="s3://${S3_BUCKET}/build/${TOOLCHAIN_BUILD_ID}/${PACKAGE}/${PACKAGE_VERSION}${PATCH_VERSION}-${COMPILER}-${COMPILER_VERSION}/${FULL_TAR_NAME}-${BUILD_LABEL}.tar.gz"
    echo "Uploading ${PACKAGE_FINAL_TGZ} to ${PACKAGE_S3_DESTINATION}"
    aws s3 cp --only-show-errors "${PACKAGE_FINAL_TGZ}" \
      "${PACKAGE_S3_DESTINATION}" \
      --region=us-west-1 || $RET_VAL
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
      untar_xz "$ARCHIVE"
      ;;
    *.zip)
      unzip -o "$ARCHIVE"
      ;;
    *)
      echo "Did not recognise archive extension: $ARCHIVE"
      return 1
      ;;
  esac
}

# Helper to portable extract tar.xz archive.
function untar_xz() {
  if [[ "$RELEASE_NAME" =~ CentOS.*5\.[[:digit:]] ]]; then
    # tar on Centos 5.8 doesn't support -J flag, so specify xzcat manually.
    tar xf "$1" --use-compress-program xzcat
  else
    tar xJf "$1"
  fi
}

# Generate a unique build ID that includes a prefix of the git hash.
function generate_build_id() {
  local GIT_HASH=$(git rev-parse --short=10 HEAD)
  # Get Jenkins build number or a unique id if we're not in jenkins.
  local UNIQUE_ID=${BUILD_NUMBER:-$(cat /proc/sys/kernel/random/uuid)}
  echo "${UNIQUE_ID}-${GIT_HASH}"
}

function enable_toolchain_autotools() {
    PATH=${BUILD_DIR}/autoconf-${AUTOCONF_VERSION}/bin/:$PATH
    PATH=${BUILD_DIR}/automake-${AUTOMAKE_VERSION}/bin/:$PATH
    PATH=${BUILD_DIR}/libtool-${LIBTOOL_VERSION}/bin/:$PATH
    ACLOCAL_PATH=${BUILD_DIR}/libtool-${LIBTOOL_VERSION}/share/aclocal:${ACLOCAL_PATH:-}
    export ACLOCAL_PATH
}
