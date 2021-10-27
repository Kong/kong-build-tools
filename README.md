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
- AWS Credentials

## Packaging a Kong Distribution

The default build task builds an Ubuntu bionic package of Kong where the Kong source is assumed to be
in a sibling directory to where this repository is cloned

```
make package-kong
ls output/
kong-0.0.0.bionic.all.deb
```

**Environment variables:**

You can find all available environment variables at the top of the [Makefile](https://github.com/Kong/kong-build-tools/blob/master/Makefile).
The most common ones are the following:

```
RESTY_IMAGE_BASE=ubuntu|centos|rhel|debian|alpine|amazonlinux
RESTY_IMAGE_TAG=18.04|20.04|6|7|8|9|10|11|latest|latest
PACKAGE_TYPE=deb|rpm|apk
```

### Details

![building kong](/docs/Package%20Kong.png?raw=true)

The Docker files in the dockerfiles directory build on each other in the following manner:

- `Dockerfile.package` builds on top of the result of `Dockerfile.kong` to package Kong using `fpm-entrypoint.sh`
- `Dockerfile.kong` builds on top of the result of `Dockerfile.openresty` to build Kong using `build-kong.sh`
- `Dockerfile.openresty` builds on top of the result of `Dockerfile.(deb|apk|rpm)` to build the Kong prerequisites using `openresty-build-tools/kong-ngx-build`
- `Dockerfile.(deb|apk|rpm)` builds the compilation / building prerequisites

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

### Debugging Tests

If you want to mirror a failed test from CI pull the test image the CI built and retag it:

```
docker pull mashape/kong-build-tools:test-33c8ceb-e2bb1fd54f8d5c12f989a801a44979b610-14
docker tag mashape/kong-build-tools:test-33c8ceb-e2bb1fd54f8d5c12f989a801a44979b610-14 mashape/kong-build-tools:test
```

If you're trying to test local Kong source code build the test image:

```
make kong-test-container
```

Now spin up the containers using docker-compose and jump into the Kong image
```
docker-compose up -d
docker-compose exec kong /bin/bash
./ci/run_tests.sh
```

## Running Functional Tests

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

Optional release ENV variables:
```
REPOSITORY_TYPE
REPOSITORY_NAME
REPOSITORY_OS_NAME
```

The defaults when the optional arguments aren't passed are (in the following order ubuntu|rhel|centos|alpine):
```
REPOSITORY_TYPE=deb|deb|rpm|generic
REPOSITORY_NAME=$KONG_PACKAGE_NAME-$REPOSITORY_TYPE
REPOSITORY_OS_NAME=ubuntu|rhel|centos|alpine-tar
```
