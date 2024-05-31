#!/usr/bin/env bash
# Copyright 2019 Cloudera Inc.
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
#
# Run any additional tasks that may be required as the last step of image creation

set -eux -o pipefail

dl_verify() {
  local url=$1
  local sha=$2
  local path=$(basename $url)
  wget --progress=dot:giga -O $path $url
  sha256sum -wc <(echo "$sha  $path")
  echo $path
}

set_default_python() {
  if ! command -v python > /dev/null; then
    if command -v python2 ; then
      # If python2 is present, set python to point to it. This happens for Redhat 8.
      alternatives --set python /usr/bin/python2
    elif command -v python3 ; then
      # Newer OSes (e.g. Redhat 9 and equivalents) make it harder to get Python 2, and we
      # need to start using Python 3 by default.
      # For these new OSes (Ubuntu 22, Redhat 9), there is no alternative entry for python,
      # so we need to create one from scratch.
      if command -v alternatives > /dev/null; then
        if alternatives --list | grep python > /dev/null ; then
          alternatives --set python /usr/bin/python3
        else
          # The alternative doesn't exist, create it
          alternatives --install /usr/bin/python python /usr/bin/python3 20
        fi
      elif command -v update-alternatives > /dev/null; then
        # This is what Ubuntu 20/22+ does. There is no official python alternative,
        # so we need to create one.
        update-alternatives --install /usr/bin/python python /usr/bin/python3 20
      else
        echo "ERROR: python/python2 don't exist"
        echo "ERROR: alternatives/update-alternatives also don't exist, so giving up..."
        exit 1
      fi
    else
        echo "ERROR: python/python2/python3 don't exist, giving up..."
    fi
  fi
  python -V > /dev/null
}

install_aws() {
  if command -v pip3 ; then
    # Use Python 3 if available
    pip3 install awscli==1.29.44
    return
  fi

  # Install the last version of pip that has official Python 2.7 support (version 20.3.4).
  if ! command -v pip 2> /dev/null; then
    dl_verify https://raw.githubusercontent.com/pypa/get-pip/20.3.4/get-pip.py 95c5ee602b2f3cc50ae053d716c3c89bea62c58568f64d7d25924d399b2d5218
    python get-pip.py "pip==20.3.4"
  fi
  # This is the last version of awscli that supports Python 2.7. It is new enough to also get
  # support relatively recent versions of Python 3 as well (e.g. Python 3.10).
  pip install awscli==1.19.112
}

install_mvn() {
  dl_verify https://native-toolchain-us-west-2.s3.us-west-2.amazonaws.com/maven/apache-maven-3.6.3-bin.tar.gz 26ad91d751b3a9a53087aefa743f4e16a17741d3915b219cf74112bf87a438c5
  tar xf apache-maven-3.6.3-bin.tar.gz
  cat <<"EOF" > /usr/local/bin/mvn
#!/bin/sh
export M2_HOME=/usr/local/apache-maven-3.6.3
export M2=$M2_HOME/bin
exec $M2/mvn "$@"
EOF
  chmod +x /usr/local/bin/mvn
}

install_ccache() {
  dl_verify https://github.com/ccache/ccache/releases/download/v3.7.12/ccache-3.7.12.tar.gz d2abe88d4c283ce960e233583061127b156ffb027c6da3cf10770fc0c7244194
  tar xvzf ccache-3.7.12.tar.gz
  (
  cd ccache-3.7.12
  ./configure
  make -j
  make install
  )
}

cd /usr/local
# NOTE: If we run these in parallel, we need to be careful about keeping the return
#       codes. Running serial for now, because performance is not important here.
set_default_python
install_aws
install_mvn
install_ccache
