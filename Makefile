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

BUILD_DIR=build_docker
STAMP_DIR=$(BUILD_DIR)/stamp
SHELL=/bin/bash -o pipefail
DISTROS = debian7 \
	debian8 \
	redhat6 \
	redhat7 \
	sles12 \
	ubuntu1204 \
	ubuntu1404 \
	ubuntu1604 \
	ubuntu1804

export TOOLCHAIN_BUILD_ID := $(shell bash -ec 'source functions.sh && generate_build_id')

$(STAMP_DIR)/impala-toolchain-% :
	@mkdir -p $(@D)
	./in-docker.py $(IN_DOCKER_ARGS) $(DOCKER_REGISTRY)$(@F) -- ./buildall.sh |sed -s 's/^/$(@F): /'
	@touch $@

all: $(foreach d,$(DISTROS),$(STAMP_DIR)/impala-toolchain-$d)

