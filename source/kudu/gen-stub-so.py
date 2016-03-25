#!/usr/bin/env python
# Copyright 2016 Cloudera Inc.
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

# Usage: ./gen-stub-so.py libkudu_client.so | g++ -shared -o /tmp/foo.so -x c++ -

import subprocess
import sys

SKIP_SYMBOLS = ["_init", "_fini"]

def main(files):
  if len(files) != 1:
    print >>sys.stderr, "usage: %s lib.so" % sys.argv[0]
    sys.exit(1)
  in_so = files[0]
  nm_out = subprocess.check_output(["nm", "--defined-only", "-D", in_so])
  print """
  static void KuduNotSupported() {
    *((char*)0) = 0;
  }
  """
  for l in nm_out.splitlines():
    addr, sym_type, name = l.split(" ")
    if name in SKIP_SYMBOLS:
      continue
    if sym_type.upper() in "TW":
      print """
 extern \"C\" void %s() {
   KuduNotSupported();
 }""" % name


if __name__ == "__main__":
  main(sys.argv[1:])
