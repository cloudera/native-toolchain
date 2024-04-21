#!/usr/bin/env bash
# Copyright 2019-2025 Cloudera Inc.
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

install_awscliv2() {
  local ARCH_NAME=$(uname -p)
  if [[ $ARCH_NAME != 'aarch64' && $ARCH_NAME != 'x86_64' ]]; then
    echo 'This script works only for x86_64 and aarch64 architectures; this is "${ARCH_NAME}"'
    return 1
  fi

  local AWS_INSTALLER_DIR=$(mktemp -d)
  local AWS_INSTALLER=${AWS_INSTALLER_DIR}/awscliv2.zip
  local AWS_INSTALLER_SIG=${AWS_INSTALLER}.sig
  wget -nv -O ${AWS_INSTALLER} "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH_NAME}.zip"

  # Verify the signature of the download ZIP file
  wget -nv -O ${AWS_INSTALLER_SIG} "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH_NAME}.zip.sig"

  cat > $AWS_INSTALLER_DIR/awscliv2-public-key << EOF
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBF2Cr7UBEADJZHcgusOJl7ENSyumXh85z0TRV0xJorM2B/JL0kHOyigQluUG
ZMLhENaG0bYatdrKP+3H91lvK050pXwnO/R7fB/FSTouki4ciIx5OuLlnJZIxSzx
PqGl0mkxImLNbGWoi6Lto0LYxqHN2iQtzlwTVmq9733zd3XfcXrZ3+LblHAgEt5G
TfNxEKJ8soPLyWmwDH6HWCnjZ/aIQRBTIQ05uVeEoYxSh6wOai7ss/KveoSNBbYz
gbdzoqI2Y8cgH2nbfgp3DSasaLZEdCSsIsK1u05CinE7k2qZ7KgKAUIcT/cR/grk
C6VwsnDU0OUCideXcQ8WeHutqvgZH1JgKDbznoIzeQHJD238GEu+eKhRHcz8/jeG
94zkcgJOz3KbZGYMiTh277Fvj9zzvZsbMBCedV1BTg3TqgvdX4bdkhf5cH+7NtWO
lrFj6UwAsGukBTAOxC0l/dnSmZhJ7Z1KmEWilro/gOrjtOxqRQutlIqG22TaqoPG
fYVN+en3Zwbt97kcgZDwqbuykNt64oZWc4XKCa3mprEGC3IbJTBFqglXmZ7l9ywG
EEUJYOlb2XrSuPWml39beWdKM8kzr1OjnlOm6+lpTRCBfo0wa9F8YZRhHPAkwKkX
XDeOGpWRj4ohOx0d2GWkyV5xyN14p2tQOCdOODmz80yUTgRpPVQUtOEhXQARAQAB
tCFBV1MgQ0xJIFRlYW0gPGF3cy1jbGlAYW1hem9uLmNvbT6JAlQEEwEIAD4CGwMF
CwkIBwIGFQoJCAsCBBYCAwECHgECF4AWIQT7Xbd/1cEYuAURraimMQrMRnJHXAUC
ZqFYbwUJCv/cOgAKCRCmMQrMRnJHXKYuEAC+wtZ611qQtOl0t5spM9SWZuszbcyA
0xBAJq2pncnp6wdCOkuAPu4/R3UCIoD2C49MkLj9Y0Yvue8CCF6OIJ8L+fKBv2DI
yWZGmHL0p9wa/X8NCKQrKxK1gq5PuCzi3f3SqwfbZuZGeK/ubnmtttWXpUtuU/Iz
VR0u/0sAy3j4uTGKh2cX7XnZbSqgJhUk9H324mIJiSwzvw1Ker6xtH/LwdBeJCck
bVBdh3LZis4zuD4IZeBO1vRvjot3Oq4xadUv5RSPATg7T1kivrtLCnwvqc6L4LnF
0OkNysk94L3LQSHyQW2kQS1cVwr+yGUSiSp+VvMbAobAapmMJWP6e/dKyAUGIX6+
2waLdbBs2U7MXznx/2ayCLPH7qCY9cenbdj5JhG9ibVvFWqqhSo22B/URQE/CMrG
+3xXwtHEBoMyWEATr1tWwn2yyQGbkUGANneSDFiTFeoQvKNyyCFTFO1F2XKCcuDs
19nj34PE2TJilTG2QRlMr4D0NgwLLAMg2Los1CK6nXWnImYHKuaKS9LVaCoC8vu7
IRBik1NX6SjrQnftk0M9dY+s0ZbAN1gbdjZ8H3qlbl/4TxMdr87m8LP4FZIIo261
Eycv34pVkCePZiP+dgamEiQJ7IL4ZArio9mv6HbDGV6mLY45+l6/0EzCwkI5IyIf
BfWC9s/USgxchg==
=ptgS
-----END PGP PUBLIC KEY BLOCK-----
EOF

  gpg --import $AWS_INSTALLER_DIR/awscliv2-public-key
  gpg --verify ${AWS_INSTALLER_SIG} ${AWS_INSTALLER}

  pushd ${AWS_INSTALLER_DIR}
  unzip ${AWS_INSTALLER}
  ./aws/install --bin-dir /usr/bin

  popd
  rm -rf ${AWS_INSTALLER_DIR}
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
install_awscliv2
install_mvn
install_ccache
