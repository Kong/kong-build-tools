# Kong Build Tools

The tools necessary to build Kong

## Prerequisites

- Kong source
- Docker
- Make

## Instructions

The default build task builds an Ubuntu xenial package of Kong where the Kong source is assumed to be
in a sibling directory to where this repository is cloned

```
cd ~
git clone git@github.com:Kong/kong.git
git clone git@github.com:Kong/kong-build-tools.git
cd kong-build-tools
make build-kong
ls output/
kong-community-edition-0.0.0.xenial.all.deb
```

Environment variables:

You can find all available environment variables at the top of the `Makefile`. The most common ones
are the following:

- KONG_SOURCE_LOCATION=/src/projects/custom-kong-location
- KONG_PACKAGE_NAME=custom-kong-name
- KONG_VERSION=v1.0.0
- RESTY_IMAGE_TAG=trusty|xenial|xenial
