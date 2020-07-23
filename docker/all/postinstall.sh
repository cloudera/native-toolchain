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
    alternatives --set python /usr/bin/python2
  fi
  python -V > /dev/null
}

install_aws() {
  if ! command -v pip 2> /dev/null; then
    dl_verify https://raw.githubusercontent.com/pypa/get-pip/fee32c376da1ff6496a798986d7939cd51e1644f/get-pip.py efe99298f3fbb1f56201ce6b81d2658067d2f7d7dfc2d412e0d3cacc9a397c61
    python get-pip.py
  fi
  # Explicitly install docutils-0.15 which is the last docutils release that works with
  # python-2.6. We have to stay compatible with python-2.6 because that's what centos:6
  # ships with.
  pip install docutils==0.15
  pip install awscli==1.16.96
}

install_mvn() {
  dl_verify https://archive.apache.org/dist/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz 26ad91d751b3a9a53087aefa743f4e16a17741d3915b219cf74112bf87a438c5
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
  dl_verify https://github.com/ccache/ccache/releases/download/v3.3.3/ccache-3.3.3.tar.gz 87a399a2267cfac3f36411fbc12ff8959f408cffd050ad15fe423df88e977e8f
  tar xvzf ccache-3.3.3.tar.gz
  (
  cd ccache-3.3.3
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
