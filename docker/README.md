# Toolchain docker images

## Building the images

Running `./buildall.sh` in the docker directory produces docker images suitable to build
the toolchain packages. The images are automatically tagged as `impala-toolchain-${distro}`.

## A note on SLES

Because SLES repositories are not public, `./buildall.sh` will skip the docker image
building process for sles12 unless the `SLES_MIRROR` environment variable is set. In
order to build this image set the `SLES_MIRROR` variable to a valid SLES SP3 mirror url.

## Using the images

The top level `in-docker.py` script sets up mounts and relevant envrionment variables and
then executes `./buildall.sh` in a container. Each container gets a copy of the `source`
directory (this copy is done using `git ls-tree` so new files must be committed in order
to be copied into the container). The `check` and `build` directories are mounted on a
per-container basis. In the host, one can find per-container directories for `source`,
`check`, and `build` under the `build_docker` directory.

## Building multiple targets at once

The top level Makefile is used for concurrency. Once the images are built the following
command should build the toolchain for redhat7 and ubuntu1604.

`make -j2 DISTROS="redhat7 ubuntu1604"`


## Working using pre-built images

Re-building the images takes a non-trivial amount of time, so it is sometimes useful to build
the toolchain on pre-built images stored in a docker registry. As long as the image name ends
with one of the distros listed in the Makefile, it is possible to specify urls in the DISTROS
make variable.

`make -j2 DISTROS="redhat7 ubuntu1604" DOCKER_REGISTRY="my-registry.com/"`


## Pushing the images

The following should list the commands required to push all `impala-toolchain-*` images to a docker registry:

```
export REGISTRY="example-registry.com/namespace`
docker images "impala-toolchain-*"
--format="docker tag {{.Repository}} $REGISTRY/{{.Repository}} && docker push $REGISTRY/{{.Repository}}"
```