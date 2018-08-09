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


# How do I contribute code?
You need to first sign and return an
[ICLA](https://github.com/cloudera/native-toolchain/blob/icla/Cloudera%20ICLA_25APR2018.pdf)
and
[CCLA](https://github.com/cloudera/native-toolchain/blob/icla/Cloudera%20CCLA_25APR2018.pdf)
before we can accept and redistribute your contribution. Once these are submitted you are
free to start contributing to native-toolchain. Submit these to CLA@cloudera.com.

## Find
We use Github issues to track bugs for this project. Find an issue that you would like to
work on (or file one if you have discovered a new issue!). If no-one is working on it,
assign it to yourself only if you intend to work on it shortly.

It’s a good idea to discuss your intended approach on the issue. You are much more
likely to have your patch reviewed and committed if you’ve already got buy-in from the
native-toolchain community before you start.

## Fix
Now start coding! As you are writing your patch, please keep the following things in mind:

First, please include tests with your patch. If your patch adds a feature or fixes a bug
and does not include tests, it will generally not be accepted. If you are unsure how to
write tests for a particular component, please ask on the issue for guidance.

Second, please keep your patch narrowly targeted to the problem described by the issue.
It’s better for everyone if we maintain discipline about the scope of each patch. In
general, if you find a bug while working on a specific feature, file a issue for the bug,
check if you can assign it to yourself and fix it independently of the feature. This helps
us to differentiate between bug fixes and features and allows us to build stable
maintenance releases.

Finally, please write a good, clear commit message, with a short, descriptive title and
a message that is exactly long enough to explain what the problem was, and how it was
fixed.

Please post your patch to the native-toolchain project at https://gerrit.cloudera.org
for review. See
[Impala's guide on using gerrit](https://cwiki.apache.org/confluence/display/IMPALA/Using+Gerrit+to+submit+and+review+patches)
to submit and review patches for instructions on how to send patches to
http://gerrit.cloudera.org, except make sure to send your patch to the native-toolchain
project instead of Impala-ASF.
