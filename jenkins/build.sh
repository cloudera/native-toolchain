#!/bin/bash
# Copyright 2020 Cloudera Inc.
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
# Build driver for containers for a Jenkins environment
# Environment variables expected:
# DISTRO_TO_BUILD: a single OS designator, or 'All' to build the containers
#   for all the OS platforms in the branch (i.e. native-toolchain/docker/*.df).
#   A single OS designator is a name of a Dockerfile in native-toolchain/docker, without
#   the extension '.df'
#   Default setting: "All"
# SLES_MIRROR: The URL to a SLES 12 package repo. The SLES12 container will be built only
#   if this variable is defined and points to a valid SLES 12 package repo.
# FORCE_REBUILD: set to "true" to delete all previous images or image layers from
#   Docker's cache on the host, "false" to leave the cache intact.
#   Default setting: "false"
# PUBLISH_CONTAINERS: set to "true" if the resulting containers should be pushed
#   to a Docker registry
#   Default: "false"
# DOCKER_REGISTRY: Points to a Docker registry where the containers should be pushed to.
#   It can be left blank if PUBLISH_CONTAINERS is not "true"

set -euo pipefail
cd $(dirname $(dirname "${BASH_SOURCE[0]}")) >/dev/null

DISTRO_PARAM=
if [[ ${DISTRO_TO_BUILD:-All} != All ]]; then
  DISTRO_PARAM="--docker_file=${DISTRO_TO_BUILD}.df"
fi

IMPALA_TOOLCHAIN_IMAGE_PATTERN="impala-toolchain-*"

if [[ ${FORCE_REBUILD:-false} = true ]]; then
  # Delete any possible toolchain images from previous builds on the same worker,
  # they may be retained in the cache
  IMPALA_TOOLCHAIN_IMAGES="$(docker images -q ${IMPALA_TOOLCHAIN_IMAGE_PATTERN})"
  if [[ -n ${IMPALA_TOOLCHAIN_IMAGES} ]]; then
    docker image rm -f ${IMPALA_TOOLCHAIN_IMAGES}
  fi
fi

pushd docker
./buildall.py ${DISTRO_PARAM}
popd

if [[ ${PUBLISH_CONTAINERS:-false} = true ]]; then
  echo "Publishing containers to registry: ${DOCKER_REGISTRY}..."
  for image in $(docker images ${IMPALA_TOOLCHAIN_IMAGE_PATTERN} \
      --format="{{.Repository}}"); do
    target="${DOCKER_REGISTRY}/$image"
    docker tag $image $target
    docker push $target
  done
fi
