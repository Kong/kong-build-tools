# Kong Build Tools

The tools necessary to build Kong

## Prerequisites

- Kong source
- Docker
- Make

## Building a Kong Distribution

The default build task builds an Ubuntu xenial package of Kong where the Kong source is assumed to be
in a sibling directory to where this repository is cloned

```
cd ~
git clone git@github.com:Kong/kong.git
git clone git@github.com:Kong/kong-build-tools.git
cd kong-build-tools
make package-kong
ls output/
kong-community-edition-0.0.0.xenial.all.deb
```

Environment variables:

You can find all available environment variables at the top of the [Makefile](https://github.com/Kong/kong-build-tools/blob/master/Makefile).
The most common ones are the following:

```
KONG_SOURCE_LOCATION=/src/projects/custom-kong-location
KONG_PACKAGE_NAME=custom-kong-name
KONG_VERSION=v1.0.0
RESTY_IMAGE_BASE=ubuntu|centos|rhel|alpine
RESTY_IMAGE_TAG=trusty|xenial|6|7|latest
```

For RedHat additionally export:
```
export REDHAT_USERNAME=rhuser
export REDHAT_PASSWORD=password
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