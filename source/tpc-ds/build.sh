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
  header $PACKAGE $PACKAGE_VERSION ${PACKAGE_STRING}.zip v${PACKAGE_VERSION} \
      v${PACKAGE_VERSION}
  cd tools

  # The value of CC will be picked up through the environment, just delete the makefile
  # line.
  sed -i -r '/^CC\s*=/d' makefile

  wrap make clean
  wrap make -j${BUILD_THREADS-4}

  # Apparently TPC-DS isn't really meant to be installed. So everything needs to be done
  # manually.
  mkdir -p "$LOCAL_INSTALL"/{bin,libexec,share/tpc-ds/query_templates} \
      "$LOCAL_INSTALL"/share/doc/tpc-ds
  cp dsdgen dsqgen "$LOCAL_INSTALL"/libexec
  cp tpcds.idx "$LOCAL_INSTALL"/share/tpc-ds
  cp ../query_templates/* "$LOCAL_INSTALL"/share/tpc-ds/query_templates
  cp ../EULA.txt How_To_Guide.doc README README_grammar.txt ReleaseNotes.txt \
      "$LOCAL_INSTALL"/share/doc/tpc-ds

  # The dialect files aren't usable until '_END' has been defined. Information online
  # suggests setting the value to an empty string. Supposedly the docs have an explanation
  # about why this is needed.
  for DIALECT in ansi db2 netezza oracle sqlserver; do
    echo 'define _END = "";' >> "$LOCAL_INSTALL"/share/tpc-ds/query_templates/$DIALECT.tpl
  done

  # The built executables can't be run directly without special options because they
  # won't find the files they need. The wrapper script below adds the special options.
  cat <<'EOF' > "$LOCAL_INSTALL"/bin/dsdgen
#!/bin/bash
DIR=$(dirname "$0")
SHARE_DIR="$DIR"/../share/tpc-ds
# Specifying -distributions as an argument to this script will override the value below.
exec "$DIR"/../libexec/dsdgen \
    -distributions "$SHARE_DIR"/tpcds.idx \
    "$@"
EOF
  chmod +x "$LOCAL_INSTALL"/bin/dsdgen

  cat <<'EOF' > "$LOCAL_INSTALL"/bin/dsqgen
#!/bin/bash
DIR=$(dirname "$0")
SHARE_DIR="$DIR"/../share/tpc-ds
# The arguments below will be overriden if they are specified as arguments to this script.
exec "$DIR"/../libexec/dsqgen \
    -distributions "$SHARE_DIR"/tpcds.idx \
    -directory "$SHARE_DIR"/query_templates \
    -input "$SHARE_DIR"/query_templates/templates.lst \
    -dialect ansi \
    "$@"
EOF
  chmod +x "$LOCAL_INSTALL"/bin/dsqgen

  footer $PACKAGE $PACKAGE_VERSION
fi
