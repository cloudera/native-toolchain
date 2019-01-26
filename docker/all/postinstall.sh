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

# Adds github's host key to ssh_known_hosts. This allows us to establish an
# ssh connection to the servers listed below without having to re-authenticate
# the server.
getent hosts github.com| xargs -n1 ssh-keyscan -t rsa,dsa >> /etc/ssh/ssh_known_hosts
