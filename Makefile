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
DISTROS = redhat7 \
	redhat8 \
	sles12 \
	ubuntu1604 \
	ubuntu1804 \
	ubuntu2004

export TOOLCHAIN_BUILD_ID := $(shell bash -ec 'source functions.sh && generate_build_id')
UPLOAD_CCACHE ?= 0
FIRST_IMAGE := $(DOCKER_REGISTRY)impala-toolchain-$(firstword $(DISTROS))
IN_DOCKER := ./in-docker.py $(IN_DOCKER_ARGS)

all: $(foreach d,$(DISTROS),$(STAMP_DIR)/impala-toolchain-$d)
ifeq ($(UPLOAD_CCACHE), 1)
	$(IN_DOCKER) $(FIRST_IMAGE) -- bash -ec 'source init.sh && upload_ccache'
endif
	@echo TOOLCHAIN_BUILD_ID is $(TOOLCHAIN_BUILD_ID)


$(STAMP_DIR)/impala-toolchain-%-upload-ccache :

$(STAMP_DIR)/impala-toolchain-% :
	@mkdir -p $(@D)
	$(IN_DOCKER) $(DOCKER_REGISTRY)$(@F) -- ./buildall.sh 2>&1|sed -s 's/^/$(@F): /'
	@touch $@
