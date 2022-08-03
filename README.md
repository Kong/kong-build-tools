# Kong Build Tools

The tools necessary to build, package and release Kong

## Prerequisites

- Kong source
- Docker
- docker-compose
- Make

All examples assume that Kong is a sibling directory of kong-build-tools and run from the kong-build-tools directory
unless otherwise specified. This behaviour can be adjusted by setting a `KONG_SOURCE_LOCATION` environment variable
```
cd ~
git clone git@github.com:Kong/kong.git
git clone git@github.com:Kong/kong-build-tools.git
cd kong-build-tools
```

Packaging arm64 architectures additionally requires:

- [Docker-machine](https://github.com/docker/machine)
- [Buildx Docker plugin](https://github.com/docker/buildx)
- AWS Credentials (or access via an instance profile)

Packaging kong-ee additionally requires:

- A `GITHUB_TOKEN` environment variable with access to Kong's private github repositories

## Building a Kong Package

```
export PACKAGE_TYPE=deb RESTY_IMAGE_BASE=ubuntu RESTY_IMAGE_TAG=20.04 # defaults if not set
make package-kong
ls output/
kong-x.y.z.20.04.all.deb
```

### Details

![building kong](/docs/Package%20Kong.png?raw=true)

The Docker files in the dockerfiles directory build on each other in the following manner:

- `Dockerfile.package` builds on top of the result of `Dockerfile.kong` to package Kong using `fpm-entrypoint.sh`
- `Dockerfile.kong` builds on top of the result of `Dockerfile.openresty` to build Kong using `build-kong.sh`
- `Dockerfile.openresty` builds on top of the result of `Dockerfile.(deb|apk|rpm)` to build the Kong prerequisites using `openresty-build-tools/kong-ngx-build`
- [github://kong/kong-build-tools-base-images](https://github.com/Kong/kong-build-tools-base-images) builds the compilation / building prerequisites

## Building a Kong Docker Image

Prerequisite: you did the packaging step
```
export KONG_TEST_CONTAINER_NAME=kong/kong:x.y.z-ubuntu-20.04 #default if not set
make build-test-container
```

## Releasing Docker Images

Prerequisite: you did the packaging step and you're logged into docker with the necessary push permissions
```
export DOCKER_RELEASE_REPOSITORY=kong/kong KONG_TEST_CONTAINER_TAG=x.y.z-ubuntu-20.04 #default if not set
make release-kong-docker-images
```

## Running Kong Tests

```
make test-kong
```

**Environment variables:**

Refer to [git://kong/.ci/run_tests.sh](https://github.com/Kong/kong/blob/master/.ci/run_tests.sh) for the authoritative environment variables.
The most common ones are the following:

```
TEST_DATABASE = "off|postgres|cassandra"
TEST_SUITE = "dbless|plugins|unit|integration"
```

### Details

![testing kong](/docs/Test%20Kong.png?raw=true)

- `docker-compose.yml` runs the result of `Dockerfile.test` as well as postgres, cassandra, grpc and redis
- `Dockerfile.test` builds on top of the result of `Dockerfile.openresty` to build Kong for development/testing
- `Dockerfile.openresty` builds on top of the result of `Dockerfile.(deb|apk|rpm)` to build the Kong prerequisites using `openresty-build-tools/kong-ngx-build`
- `Dockerfile.(deb|apk|rpm)` builds the compilation / building prerequisites

## Running Packaging / Smoke Tests

The Kong Build Tools functional tests suite run a tests on a Kong package which we then integrate
into our official docker build image dockerfile.

```
make package-kong
make test
```

### Details

![releasing kong](/docs/Release%20Kong.png?raw=true)

`test/build_container.sh` clones `git://kong/docker-kong` and provides the Dockerfile with a packaged Kong asset

**01-package**

Validates the version required per `git://kong/.requirements` of our prerequisites is what ended up being installed.
Also does some rudimentary checks of the systemd and logrotate we include with our packages

**02-api**

Functional Admin API and Proxy tests.

## Releasing Kong

The same defaults that applied when creating a packaged version of Kong apply to releasing said package
to our internal server and can be changed by environment variables. Presumes that the package you want to release
already exists in the output directory.

```
export PULP_USR=user
export PULP_PSW=password
export RESTY_IMAGE_BASE=seeabove
export RESTY_IMAGE_TAG=seeabove
export KONG_PACKAGE_NAME=somename
make package-kong
make release-kong
```

Required release ENV variables:
```
PULP_USR
PULP_PSW
```
