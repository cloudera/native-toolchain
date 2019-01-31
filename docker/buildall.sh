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
# Build and tag all docker images. Only outputs the tags to stdout.

set -u
set -e

for i in *.df; do
  tag=impala-toolchain-${i%.*}
  BUILD_ARGS=(build -f $i -t $tag)
  if [[ $i =~ "sles12" ]]; then
    if [[ -n "${SLES_MIRROR:-""}" ]]; then
      BUILD_ARGS+=(--build-arg="SLES_MIRROR=$SLES_MIRROR")
    else
      >&2 echo "Skipping sles 12 because SLES_MIRROR is empty"
      continue
    fi
  fi
  >&2 echo "Building image: $tag"
  docker ${BUILD_ARGS[@]} . >&2
  echo $tag
done
