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
#
# Build and tag all docker images (or a single image specified by --docker_image).
# Output to stdout the tags that were succesfully built.
import argparse
import glob
import logging
import os
import subprocess
import sys

LOG = logging.getLogger('buildall.py')

# Used with --multi for multi-platform builds. Requires QEMU and a docker-container
# builder, see README.md for setup.
ARM_PLATFORMS = ['redhat8', 'redhat9', 'ubuntu2004', 'ubuntu2204', 'ubuntu2404']

def main():
  logging.basicConfig(level=logging.INFO)
  parser = argparse.ArgumentParser()
  parser.add_argument("--docker_file", help="An individual docker file to build")
  parser.add_argument("--registry", help="Publish images to the specified registry")
  parser.add_argument("--builder", help="Specify a buildx builder")
  parser.add_argument("--multi", action='store_true',
                      help="Build multi-platform images; disables loading in Docker")
  args = parser.parse_args()

  if args.docker_file:
    if not os.path.exists(args.docker_file):
      sys.exit("Docker file {0} does not exist".format(args.docker_file))
    docker_file_list = [args.docker_file]
  else:
    docker_file_list = glob.glob('*.df')

  procs = []
  for df in docker_file_list:
    osname = df[:-3]
    tag = 'impala-toolchain-%s' % osname
    log_file = tag + '.log'
    if args.registry:
      tag = "%s/%s" % (args.registry, tag)

    build_cmd = ['docker', 'buildx', 'build', '-f', df, '-t', tag]
    if args.builder:
      build_cmd += ['--builder', args.builder]
    if args.registry:
      build_cmd.append('--push')
    elif not args.multi:
      build_cmd.append('--load')
    if args.multi and osname in ARM_PLATFORMS:
      build_cmd.append('--platform=linux/amd64,linux/arm64')
    if 'sles12' in osname:
      # SLES_MIRROR must be non=empty if defined
      if 'SLES_MIRROR' in os.environ and os.environ['SLES_MIRROR']:
        build_cmd += ['--build-arg=SLES_MIRROR=%s' % os.environ['SLES_MIRROR']]
      else:
        LOG.warning('Skipping sles12 because SLES_MIRROR is empty')
        continue
    build_cmd.append('.')
    LOG.info('Running: %s Log: %s', ' '.join(build_cmd), log_file)
    with open(log_file, 'w') as f:
      procs.append((subprocess.Popen(build_cmd, stdout=f, stderr=f), tag, log_file))

  exit = 0
  for p, tag, log_file in procs:
    if p.wait():
      exit = 1
      LOG.error('Error building %s. Refer to logs at %s\n', tag, log_file)
    else:
      print(tag)
  sys.exit(exit)


if __name__ == '__main__':
  main()
