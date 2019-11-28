# Kong Build Tools

The tools necessary to build Kong

## Prerequisites

- Kong source
- Docker
- Make

Building non x86_64 architectures additionally requires:

- [Docker-machine](https://github.com/docker/machine)
- [Buildx Docker plugin](https://github.com/docker/buildx)
- AWS Credentials

## Building a Kong Distribution

The default build task builds an Ubuntu xenial package of Kong where the Kong source is assumed to be
in a sibling directory to where this repository is cloned

```
cd ~
git clone git@github.com:Kong/kong.git
git clone git@github.com:Kong/kong-build-tools.git
cd kong-build-tools
make build-kong
ls output/
kong-0.0.0.xenial.all.deb
```

Environment variables:

You can find all available environment variables at the top of the [Makefile](https://github.com/Kong/kong-build-tools/blob/master/Makefile).
The most common ones are the following:

```
KONG_SOURCE_LOCATION=/src/projects/custom-kong-location
KONG_PACKAGE_NAME=custom-kong-name
KONG_VERSION=v1.0.0
RESTY_IMAGE_BASE=ubuntu|centos|rhel|debian|alpine|amazonlinux
RESTY_IMAGE_TAG=xenial|bionic|6|7|8|jessie|stretch|latest|latest
PACKAGE_TYPE=deb|rpm|apk
```

For RedHat additionally export:
```
export REDHAT_USERNAME=rhuser
export REDHAT_PASSWORD=password
```

## Building a Container

Sometimes it's useful to have a docker image with the Kong asset installed that you just built.

```
export KONG_TEST_CONTAINER_NAME=kong:testing
make build-test-container
```

## Testing

*Prerequisites:*

- Docker
- [Kind](https://github.com/kubernetes-sigs/kind)
- [Helm](https://github.com/helm/helm)

```
make test
```

## Functional Tests

The Kong functional tests use [Tavern](https://taverntesting.github.io/).

*Prerequisites*

- Docker
- A Packaged Kong Release (`make build-kong`)

```
make test
```

Will run the functional tests against the defaults specified in the Makefile prefixed with `TEST_`

The available ENV's and their defaults are as follows

```
TEST_ADMIN_PROTOCOL?=http://
TEST_ADMIN_PORT?=8001
TEST_HOST?=localhost
TEST_ADMIN_URI?=$(TEST_ADMIN_PROTOCOL)$(TEST_HOST):$(TEST_ADMIN_PORT)
TEST_PROXY_PROTOCOL?=http://
TEST_PROXY_PORT?=8000
TEST_PROXY_URI?=$(TEST_PROXY_PROTOCOL)$(TEST_HOST):$(TEST_PROXY_PORT)
```

### Developing Functional Tests

With the same prerequisites as running functional tests

```
make test
make develop-tests
py.test test_your_test.tavern.yaml # Expect warnings about https and structure different
```

## Releasing a Kong Distribution

The same defaults that applied when creating a packaged version of Kong apply to releasing said package
to bintray and can be changed by environment variables. Presumes that the package you want to release
already exists in the output directory.

```
export BINTRAY_USR=user
export BINTRAY_KEY=key
export RESTY_IMAGE_BASE=seeabove
export RESTY_IMAGE_TAG=seeabove
export KONG_PACKAGE_NAME=somename
export KONG_VERSION=1.2.3
make release-kong
```

Required release ENV variables:
```
BINTRAY_USR
BINTRAY_KEY
```

Required release ENV variables that have defaults if they are not set:
```
RESTY_IMAGE_BASE
RESTY_IMAGE_TAG
KONG_PACKAGE_NAME
KONG_VERSION
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

bintray.com/kong/$REPOSITORY_NAME/$REPOSITORY_OS_NAME/$KONG_VERSION/$KONG_PACKAGE_NAME-$KONG_VERSION.$OUTPUT_FILE_SUFFIX
```

Using all defaults one would end up with

```
bintray.com/kong/kong-deb/ubuntu/0.0.0/kong-0.0.0.xenial.all.deb
```