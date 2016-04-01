#!/usr/bin/env bash
# Copyright 2016 Cloudera Inc.
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

set -euo pipefail

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR

download_dependency $PACKAGE "${PACKAGE_STRING}.zip" $THIS_DIR

if needs_build_package; then
  header $PACKAGE $PACKAGE_VERSION ${PACKAGE_STRING}.zip tpch_${PACKAGE_VERSION//./_} \
      tpch_${PACKAGE_VERSION//./_}
  cd dbgen

  # TCP provides a "makefile.suite" which is a sort of template. They expect people to
  # make a copy of it as "makefile" and modify it to as needed. The steps below could
  # be done using the toolchain's patch system but the expectation is that this needs to
  # be done for all versions and the toolchain patch system isn't setup for that. The
  # patch system probably isn't worth modifying for this one case.
  cp makefile.suite makefile

  # The value of CC will be picked up through the environment, just delete the makefile
  # line.
  sed -i -r '/^CC\s*=/d' makefile

  # See the makefile for a description of the options below.
  sed -i -r 's/^(DATABASE\s*=)/\1 DB2/' makefile
  sed -i -r 's/^(MACHINE\s*=)/\1 LINUX/' makefile
  sed -i -r 's/^(WORKLOAD\s*=)/\1 TPCH/' makefile

  # -DEOL_HANDLING affects data generation. Data is generated row-wise with a separator
  # between values. With this option, the final value in a row will not have a trailing
  # separator. This is done for better compatibility with Hadoop and Impala.
  sed -i -r 's/^(CFLAGS\s*=)/\1 -DEOL_HANDLING/' makefile

  wrap make clean
  wrap make -j${BUILD_THREADS-4}

  # Apparently TPC-H isn't really meant to be installed. So everything needs to be done
  # manually.
  mkdir -p "$LOCAL_INSTALL"/{bin,libexec,share/tpc-h/queries} \
      "$LOCAL_INSTALL"/share/doc/tpc-h
  cp dbgen qgen "$LOCAL_INSTALL"/libexec
  cp dists.dss "$LOCAL_INSTALL"/share/tpc-h
  cp queries/* "$LOCAL_INSTALL"/share/tpc-h/queries
  cp README  "$LOCAL_INSTALL"/share/doc/tpc-h

  # The built executables can't be run directly without a special option because they
  # won't find the dists.dss file they need. The wrapper script below adds the special
  # option.
  cat <<'EOF' > "$LOCAL_INSTALL"/bin/dbgen
#!/bin/bash
DIR=$(dirname "$0")

# Specifying -b as an argument to this script will override the value below.
exec "$DIR"/../libexec/dbgen -b "$DIR"/../share/tpc-h/dists.dss "$@"
EOF
    chmod +x "$LOCAL_INSTALL"/bin/dbgen

  cat <<'EOF' > "$LOCAL_INSTALL"/bin/qgen
#!/bin/bash
DIR=$(dirname "$0")

# Apparently the query dir can only be set through the environment.
: ${DSS_QUERY:="$DIR/../share/tpc-h/queries"}
export DSS_QUERY

# Specifying -b as an argument to this script will override the value below.
exec "$DIR"/../libexec/qgen -b "$DIR"/../share/tpc-h/dists.dss "$@"
EOF
    chmod +x "$LOCAL_INSTALL"/bin/qgen

  footer $PACKAGE $PACKAGE_VERSION
fi
