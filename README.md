# Building Dependencies

Running `./buildall.sh` in the toplevel directory should be enough to
produce the binaries.


# Specific Package

To build a specific package run:

    ./build.sh package package.version

 for example:

    ./build.sh python 2.7.10

 Its possible as well to build several packages at once.

    ./build.sh python 2.7.10 llvm 3.3-p1

Here, the arguments are package version pairs.

# Mac OS X

To build on Mac we cannot use a custom GCC, so we have to use
the system compiler:

    SYSYTEM_GCC=1 DEBUG=1 ./buildall.sh
