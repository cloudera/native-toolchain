#!/usr/bin/env python
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


"""
Script that sets up an environment used in order to perform full (or partial)
toolchain builds. Dockerfiles for images known to work with this script
can be found in the docker/ directory and the tags for the produced images
can be seen in the KNOWN_DOCKER_TAGS variable.

This script uses a combination of docker options and mount points to ensure
that the produced artifacts are owned by the correct user and to allow each
container to work with its own copy of the files.
 * The source dir gets copied (using git ls-files) at the start of the build
 * The build and check directories get mounted per-container.

The resulting artifacts of the build and the logs can be found under
docker_build/$img/build and docker_build/$img/check respectively.

One directory is created per docker-tag. Under this directory the familiar
build, check, and source directories can be found.

--docker-args arguments are passed in verbatim to docker. So for example:

in-docker.py --docker-args="-u root --env FOO=BAR" impala-toolchain-centos6 -- bash -c 'whoami; echo $FOO'
root
BAR

To get an interactive terminal:
in-docker.py --docker-args="-t" impala-toolchain-centos6 -- bash
"""

import argparse
import errno
import logging
import os
import shlex
import subprocess
import sys
import textwrap

LOG = logging.getLogger()


# Maps docker images to BUILD_TARGET_LABELs which is ultimately included
# in the path for each built package. The mapping that follows is also present
# in bin/bootstrap_toolchain.py, which depends on these strings.
KNOWN_DOCKER_TAGS = {'impala-toolchain-redhat7': 'ec2-package-centos-7',
                     'impala-toolchain-redhat8': 'ec2-package-centos-8',
                     'impala-toolchain-sles12': 'ec2-package-sles-12',
                     'impala-toolchain-ubuntu1604': 'ec2-package-ubuntu-16-04',
                     'impala-toolchain-ubuntu1804': 'ec2-package-ubuntu-18-04',
                     'impala-toolchain-ubuntu2004': 'ec2-package-ubuntu-20-04'}

__SOURCE_DIR = os.path.abspath(os.path.dirname(os.path.realpath(__file__)))
TARGET_DIR = '/mnt'

DOCKER_CMD = ['docker',
              'create',
              '-i',
              '-w', TARGET_DIR,
              '-u', '%s:%s' % (os.geteuid(), os.getgid()),
              '-v', '/etc/passwd:/etc/passwd:ro',
              '-v', '/etc/group:/etc/group:ro',
              '-v', '{SOURCE_DIR}:{TARGET_DIR}'.format(SOURCE_DIR=__SOURCE_DIR, TARGET_DIR=TARGET_DIR)]


def parse_args():
  parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
  parser.add_argument('--docker-args', default='', help=textwrap.dedent('''\
                                                                        Arguments that will be passed in verbatim to `docker create`.
                                                                        Note that since argparse will attempt to parse all options here, it\'s usually
                                                                        required to quote this argument as follows:
                                                                        --docker-args="--arg1 --arg2 --etc"

                                                                        Refer to docker-create(1) for information about the supported arguments.
                                                                        '''))
  parser.add_argument('DOCKER_IMAGE', help='Docker image to use, tags of images known to work are: %s' % ', '.join(KNOWN_DOCKER_TAGS))
  parser.add_argument('COMMAND', nargs='+')
  return parser.parse_args()


def mkdir_p(d):
  try:
    os.makedirs(d)
  except OSError as e:
    if e.errno != errno.EEXIST:
      raise


def prepare_source_dir():
  # Since we mount our entire SOURCE_DIR, create these directories ourselves to prevent root owned directories.
  # mkdir foo
  # docker run -v $(pwd):/mnt -v $(pwd)/foo:/mnt/baz -w /mnt ubuntu find . -user root; find . -user root;
  # ./baz
  for d in ['build', 'ccache', 'check', 'source']:
    mkdir_p(d)


def create_mounts_cmd(distro_build_dir):
  cmd = []
  for d in ['build', 'check', 'source']:
    srcdir = os.path.join(distro_build_dir, d)
    tgtdir = os.path.join(TARGET_DIR, d)
    # Create the mountpoints first. Otherwise docker creates root owned directories.
    mkdir_p(srcdir)
    assert ':' not in srcdir and ':' not in tgtdir, ': in source or targetdir'
    cmd += ['-v', '%s:%s' % (srcdir, tgtdir)]
  return cmd


def passthrough_env(image):
  env_vars = ['AWS_ACCESS_KEY_ID',
              'AWS_SECRET_ACCESS_KEY',
              'AWS_SESSION_TOKEN',
              'BUILD_TARGET_LABEL',
              'CLEAN',
              'CLEAN_TMP_AFTER_BUILD',
              'DEBUG',
              'FAIL_ON_PUBLISH',
              'KUDU_GITHUB_URL',
              'KUDU_VERSION',
              'PRODUCTION',
              'PUBLISH_DEPENDENCIES',
              'PUBLISH_DEPENDENCIES_S3',
              'PUBLISH_DEPENDENCIES_ARTIFACTORY',
              'SYSTEM_GCC',
              'SYSTEM_CMAKE',
              'S3_BUCKET',
              'TOOLCHAIN_BUILD_ID']
  if 'BUILD_TARGET_LABEL' not in os.environ:
    # Discard docker registry prefix, if it exists.
    matches = filter(image.endswith, KNOWN_DOCKER_TAGS)
    if matches:
      assert len(matches) == 1
      os.environ['BUILD_TARGET_LABEL'] = KNOWN_DOCKER_TAGS[matches[0]]
  for program in os.listdir('source'):
    env_vars.append(program.upper() + '_VERSION')
  ret = []
  for e in env_vars:
    if e in os.environ:
      ret += ['-e', '%s=%s' % (e, os.environ[e])]
  return ret


def copy_source_dir(distro_build_dir):
  git = subprocess.Popen(['git', 'ls-tree', '--full-tree', '-r', '--name-only', 'HEAD', 'source/'], stdout=subprocess.PIPE)
  xargs = subprocess.Popen(['xargs', '-I{}', 'cp', '--parents', '{}', distro_build_dir], stdin=git.stdout)
  xargs.communicate()
  if git.poll() or xargs.poll():
    raise Exception('Error copying source directory into container mount.')


def add_ccache_opts():
  if os.environ.get('USE_CCACHE', '1').lower() not in ('1', 'true'):
    return []
  # In order to make it easier to handle, we keep a single ccache directory for all containers
  ccache_src = os.environ.get('CCACHE_DIR', os.path.join(__SOURCE_DIR, 'build_docker/ccache'))
  ccache_tgt = os.path.join(TARGET_DIR, 'ccache')
  mkdir_p(ccache_src)
  return ['-e', 'USE_CCACHE=1',
          '-v', '{ccache_src}:{ccache_tgt}'.format(ccache_src=ccache_src, ccache_tgt=ccache_tgt),
          '-e', 'CCACHE_DIR={ccache_tgt}'.format(ccache_tgt=ccache_tgt)]


def main():
  args = parse_args()
  logging.basicConfig(level=logging.INFO, format='%(message)s')

  prepare_source_dir()
  build_dir = os.environ.get('BUILD_DIR', os.path.join(__SOURCE_DIR, 'build_docker'))
  distro_build_dir = os.path.join(build_dir, args.DOCKER_IMAGE.replace('/', '_'))

  cmd = DOCKER_CMD
  cmd += create_mounts_cmd(distro_build_dir)
  cmd += add_ccache_opts()
  cmd += passthrough_env(args.DOCKER_IMAGE)
  cmd += shlex.split(args.docker_args)
  cmd += [args.DOCKER_IMAGE]
  cmd += args.COMMAND

  copy_source_dir(distro_build_dir)
  container_id = None
  try:
    LOG.info('Running:\n%s' % textwrap.fill(' '.join(cmd), 120, break_on_hyphens=False, break_long_words=False))
    container_id = subprocess.check_output(cmd).strip()
    subprocess.check_call(['docker', 'start', '--attach', '--interactive', container_id])
  except subprocess.CalledProcessError as e:
    if e.output:
      LOG.error(e.output + '\n')
    sys.exit(e.returncode)
  finally:
    if container_id:
      subprocess.check_output(['docker', 'stop', container_id])
      subprocess.check_output(['docker', 'rm', container_id])


if __name__ == '__main__':
  main()
