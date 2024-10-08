# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

cmake_minimum_required(VERSION 3.9)

project(CallOnceHack CXX)

# Version number of package
SET(CPACK_PACKAGE_VERSION_MAJOR "1")
SET(CPACK_PACKAGE_VERSION_MINOR "0")
SET(CPACK_PACKAGE_VERSION_PATCH "0")

SET(CPACK_GENERATOR "TGZ")
SET(CPACK_PACKAGE_VENDOR "Apache Impala")
SET(CPACK_PACKAGE_CONTACT "Apache Impala <dev@impala.apache.org>")

INCLUDE(CPack)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(SOURCE_FILES
  calloncehack.cc
)

include_directories(
  ${CMAKE_CURRENT_SOURCE_DIR}
)

add_library(calloncehack SHARED ${SOURCE_FILES})

install(TARGETS calloncehack DESTINATION lib)

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/calloncehack.h"
  DESTINATION "include/"
)
