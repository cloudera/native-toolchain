# Toolchain docker images

## Building the images

Running `./buildall.py` in the docker directory produces docker images suitable to build
the toolchain packages. The images are automatically tagged as `impala-toolchain-${distro}`.
To build a single docker image, use the --docker_file argument for buildall.py.

## A note on SLES

Because SLES repositories are not public, `./buildall.py` will skip the docker image
building process for sles12 unless the `SLES_MIRROR` environment variable is set. In
order to build this image set the `SLES_MIRROR` variable to a valid SLES SP3 mirror url.

## Using the images

The top level `in-docker.py` script sets up mounts and relevant envrionment variables and
then executes `./buildall.py` in a container. Each container gets a copy of the `source`
directory (this copy is done using `git ls-tree` so new files must be committed in order
to be copied into the container). The `check` and `build` directories are mounted on a
per-container basis. In the host, one can find per-container directories for `source`,
`check`, and `build` under the `build_docker` directory.

## Building multiple targets at once

The top level Makefile is used for concurrency. Once the images are built the following
command should build the toolchain for redhat7 and ubuntu1604.

`make -j2 DISTROS="redhat7 ubuntu1604"`

## Pushing the images

Specify `./buildall.py --registry=example-registry.com/namespace` to publish images to a
Docker registry. If images were previously built with [buildall.py](buildall.py), they
should rebuild quickly from the build cache before pushing.

## Building multi-platform images

Docker buildx supports building multi-platform images and combining them in a single tag.
`./buildall.py --multi` supports this, but requires that you install QEMU
```
apt install binfmt-support qemu-user-static qemu-system-x86
```

and create a [docker-container](https://docs.docker.com/engine/reference/commandline/buildx_create/#docker-container-driver)
builder
```
docker buildx create --use
```

Note that building multi-platform images requires disabling loading them into the local
`docker images`; the only way to publish them is with the `--registry` option.

## Working using pre-built images

Re-building the images takes a non-trivial amount of time, so it is sometimes useful to build
the toolchain on pre-built images stored in a docker registry. As long as the image name ends
with one of the distros listed in the Makefile, it is possible to specify urls in the DISTROS
make variable.

`make -j2 DISTROS="redhat7 ubuntu1604" DOCKER_REGISTRY="my-registry.com/"`
