#!/usr/bin/env python
# Copyright 2015 Cloudera Inc.
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

import subprocess

# =====================================================================
# Package metadata
# =====================================================================

PACKAGE_METADATA = {}


def add_package_version(pkg_name, version, deps=None):
    if deps is None:
        deps = []
    if pkg_name not in PACKAGE_METADATA:
        PACKAGE_METADATA[pkg_name] = {}
    spec = {
        'dependencies': deps
    }
    PACKAGE_METADATA[pkg_name][version] = spec

# ---------------------------------------------------------------------
# boost

add_package_version('boost', '1.57.0')

# ----------------------------------------------------------------------
# boost

add_package_version('python', '2.7.10')

# ---------------------------------------------------------------------
# cmake

add_package_version('cmake', '3.2.3')

# ---------------------------------------------------------------------
# LLVM

add_package_version('llvm', '3.3-p1')
add_package_version('llvm', '3.7.0')

# ---------------------------------------------------------------------
# SASL

add_package_version('cyrus_sasl', '2.1.23')
add_package_version('cyrus_sasl', '2.1.26')

# ---------------------------------------------------------------------
# libevent

add_package_version('libevent', '1.4.15')

# ---------------------------------------------------------------------
# openssl

add_package_version('openssl', '1.0.1p')

# ---------------------------------------------------------------------
# zlib

add_package_version('zlib', '1.2.8')

# ---------------------------------------------------------------------
# thrift

_deps = ['libevent=1.4.15', 'boost=1.57.0', 'zlib=1.2.8', 'openssl=1.0.1p']
add_package_version('thrift', '0.9.0-p2', _deps)
add_package_version('thrift', '0.9.0-p4', _deps)
add_package_version('thrift', '0.9.2-p2', _deps)

# ---------------------------------------------------------------------
# gflags

add_package_version('gflags', '2.0')

# ---------------------------------------------------------------------
# glog

_deps = ['gflags=2.0']
add_package_version('glog', '0.3.2-p1', _deps)
add_package_version('glog', '0.3.3-p1', _deps)

# ---------------------------------------------------------------------
# gperftools

add_package_version('gperftools', '2.0-p1')
add_package_version('gperftools', '2.3')

# ---------------------------------------------------------------------
# googletest

add_package_version('gtest', '1.6.0')
add_package_version('googletest', '20151222')

# ---------------------------------------------------------------------
# snappy

add_package_version('snappy', '1.0.5')

# ---------------------------------------------------------------------
# lz4

add_package_version('lz4', 'svn')

# ---------------------------------------------------------------------
# re2

add_package_version('re2', '20130115')
add_package_version('re2', '20130115-p1')

# ---------------------------------------------------------------------
# openldap

add_package_version('openldap', '2.4.25')

# ---------------------------------------------------------------------
# avro-c

add_package_version('avro', '1.7.4-p3')

# ---------------------------------------------------------------------
# rapidjson

add_package_version('rapidjson', '0.11')

# ---------------------------------------------------------------------
# bzip2

add_package_version('bzip2', '1.0.6-p1')

# ---------------------------------------------------------------------
# gdb

# ---------------------------------------------------------------------
# libunwind

add_package_version('libunwind', '1.1')

# ---------------------------------------------------------------------
# breakpad

add_package_version('breakpad', '20150612-p1')

# ======================================================================
# Install a set of packages
# ======================================================================

BUILD_SCRIPT_PREAMBLE = """
#!/usr/bin/env bash
# Exit on non-true return value
set -e
# Exit on reference to uninitialized variable
set -u
set -o pipefail

# The init.sh script contains all the necessary logic to setup the environment
# for the build process. This includes setting the right compiler and linker
# flags.
source ./init.sh
"""


class ScriptBuilder(object):

    def __init__(self, libraries, package_registry=None):
        self.libraries = libraries
        self.package_registry = package_registry or PACKAGE_METADATA

    def build(self):
        script = self.get_build_script()
        proc = subprocess.Popen(script, shell=True)
        proc.wait()

    def get_build_script(self):
        libraries_ordered = self._get_build_order()

        steps = []
        for libname, version in libraries_ordered:
            build_line = self._build_library(libname, version)
            steps.append(build_line)

        return BUILD_SCRIPT_PREAMBLE + '\n'.join(steps)

    def _get_build_order(self):
        memo = {}
        for lib in self.libraries:
            name, version = _parse_lib(lib)
            self._walk(name, version, memo)

        return [x1 for x0, x1 in
                sorted((v, k) for k, v in memo.items())]

    def _walk(self, name, version, memo):
        if (name, version) in memo:
            return

        for dep in self._get_deps(name, version):
            depname, depversion = _parse_lib(dep)
            self._walk(depname, depversion, memo)

        memo[name, version] = len(memo)

    def _build_library(self, name, version):
        tokens = [_lib_env_decl(*_parse_lib(dep))
                  for dep in self._get_deps(name, version)]

        tokens.append(_lib_env_decl(name, version))

        tokens.append('$SOURCE_DIR/source/{0}/build.sh'.format(name))
        return ' '.join(tokens)

    def _get_deps(self, name, version):
        meta = self.package_registry[name]
        if version not in meta:
            raise KeyError('No {0} build metadata for version: {1}'
                           .format(name, version))
        return meta[version].get('dependencies', [])


def _lib_env_decl(name, version):
    return '{0}_VERSION={1}'.format(name.upper(), version)


def _parse_lib(lib):
    return lib.split('=')
