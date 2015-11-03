# Building Dependencies

Running `./build.sh` in the toplevel directory should be enough to
produce the binaries.


# Specific Package

To build a specific package run:

   BUILD_ALL=0 BUILD_XXX=1 ./buildall.sh

where `XXX` is one of the packages from source.

# Mac OS X

To build on Mac we cannot use a custom GCC, so we have to use
the system compiler:

    SYSYTEM_GCC=1 DEBUG=1 ./buildall.sh
