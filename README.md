# Building Dependencies

Running `./buildall.sh` in the top level directory produces the binaries for
the current versions of all packages. This will likely take several hours the
first time you run it. If you rerun the script, it checks the `build` and
`check` directories for preexisting artifacts and only regenerates them
if not present.

If you want to build all versions of all packages, you can set the
environment variable `BUILD_HISTORICAL=1`. Be warned this will take a
long time.

  BUILD_HISTORICAL=1 buildall.sh

# Sources
By default, the sources for the different packages are downloaded from an S3
bucket provided by Cloudera. If desired, it's possible to download the exact
version of the package and simply move it to the source directory.

For example, if you want to download the gcc source manually, find the
gcc-4.9.2.tar.gz archive and copy it to source/gcc. If the file is present it
will not be downloaded again.

# Building a Specific Package

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

    SYSTEM_GCC=1 DEBUG=1 ./buildall.sh
