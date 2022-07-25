# openresty-build-tools

Reusable script for bootstrapping core components needed for Kong development.

This script builds different flavors of OpenSSL, OpenResty and LuaRocks depends on command
line arguments passed to it. It does this independently of what the base O/S library version
is so you always ends up with the same binary, every time.

# Synopsis
```
./kong-ngx-build -p buildroot --openresty 1.13.6.2 --openssl 1.1.1b --luarocks 3.0.4 --pcre 8.43 --debug
```

# Build

## Prerequisites

These are the needed tools and libraries that aren't installed out of the box on Ubuntu and Fedora, respectively.  Run one of these, either as root or with `sudo`.

Ubuntu/Debian:

```shell
sudo apt update \
&& sudo apt install -y \
    automake \
    build-essential \
    curl \
    docker \
    docker-compose \
    git \
    libpcre3 \
    libyaml-dev \
    m4 \
    openssl \
    perl \
    procps \
    unzip \
    zlib1g-dev \
    valgrind \
    rustc \
    g++
```

Fedora:

```shell
dnf install \
    automake \
    docker \
    docker-compose \
    gcc \
    gcc-c++ \
    git \
    libyaml-devel \
    make \
    patch \
    pcre-devel \
    unzip \
    zlib-devel \
    valgrind \
    rustc \
    g++
```

## Versions

To run the script we need to find out what versions of dependencies the current build of Kong requires, and use that as arguments. <span class="x x-first x-last">Their </span>exact versions can be found on the [`.requirements`](https://github.com/Kong/kong/blob/master/.requirements) file.
You could manually copy the versions, or follow the steps below.

```shell
# get .requirements and then
export RESTY_VERSION=$(grep -oP 'RESTY_VERSION=\K.*' .requirements)
export RESTY_LUAROCKS_VERSION=$(grep -oP 'RESTY_LUAROCKS_VERSION=\K.*' .requirements)
export RESTY_OPENSSL_VERSION=$(grep -oP 'RESTY_OPENSSL_VERSION=\K.*' .requirements)
export RESTY_PCRE_VERSION=$(grep -oP 'RESTY_PCRE_VERSION=\K.*' .requirements)
export RESTY_LMDB_VERSION=$(grep -oP 'RESTY_LMDB_VERSION=\K.*' .requirements)
export RESTY_EVENTS_VERSION=$(grep -oP 'RESTY_EVENTS_VERSION=\K.*' .requirements)
export ATC_ROUTER_VERSION=$(grep -oP 'ATC_ROUTER_VERSION=\K.*' .requirements)
export KONG_NGINX_MODULE_BRANCH=$(grep -oP 'KONG_NGINX_MODULE_BRANCH=\K.*' .requirements)
```

You could use root or call with sudo if you want to install to `/usr/local` or anywhere require that privilege.

```shell
# Somewhere you're able or prefer to build
export BUILDROOT=$(realpath ~/kong-dep)
mkdir ${BUILDROOT} -p

cd kong-build-tools/openresty-build-tools

# You might want to add also --debug
./kong-ngx-build -p ${BUILDROOT} \
  --openresty ${RESTY_VERSION} \
  --luarocks ${RESTY_LUAROCKS_VERSION} \
  --openssl ${RESTY_OPENSSL_VERSION} \
  --pcre ${RESTY_PCRE_VERSION}\
  --resty-lmdb ${RESTY_LMDB_VERSION}\
  --resty-events ${RESTY_EVENTS_VERSION}\
  --atc-router ${ATC_ROUTER_VERSION}\
  --kong-nginx-module ${KONG_NGINX_MODULE_BRANCH}\
  --debug # include this for debugging
```

After that, we could set environment variables needed for kong building with commands below:

```shell
# Add those paths for later use
export OPENSSL_DIR=${BUILDROOT}/openssl
export CRYPTO_DIR=${BUILDROOT}/openssl
export PATH=${BUILDROOT}/luarocks/bin:${BUILDROOT}/openresty/bin:${PATH}
eval $(luarocks path)
```

The `$OPENSSL_DIR` variable is needed when compiling Kong, to make sure it uses the correct version of OpenSSL.

You could add these lines to your `.profile` or `.bashrc` file.

# Usage
```
$ ./kong-ngx-build -h
Build basic components (OpenResty, OpenSSL and LuaRocks) for Kong.

Usage: ./kong-ngx-build [options...] -p <prefix> --openresty <openresty_ver> --openssl <openssl_ver>

Required arguments:
  -p, --prefix <prefix>              Location where components should be installed.
      --openresty <openresty_ver>    Version of OpenResty to build, such as 1.13.6.2.

Semi-Optional arguments:
      --openssl <openssl_ver>        Version of OpenSSL to build, such as 1.1.1c.

      --boringssl <boringssl_ver>    Version of BoringSSL to build

  One of `--openssl` or `--boringssl` needs to be provided. The default behavior

                                     is to build OpenSSL.

Optional arguments:
      --ssl-provider                 Specify a provider for SSL libraries.

                                     (Can be set to "openssl" or "boringssl")

      --no-openresty-patches         Do not apply openresty-patches while compiling OpenResty.
                                     (Patching is enabled by default)

      --no-kong-nginx-module         Do not include lua-kong-nginx-module while patching and compiling OpenResty.
                                     (Patching and compiling is enabled by default for OpenResty > 1.13.6.1)

      --kong-nginx-module <branch>   Specify a lua-kong-nginx-module branch to use when patching and compiling.
                                     (Defaults to "master")

      --no-resty-lmdb                Do not include lua-resty-lmdb while patching and compiling OpenResty.

      --resty-lmdb <branch>          Specify a lua-resty-lmdb branch to use when patching and compiling.
                                     (Defaults to "master")

      --luarocks <luarocks_ver>      Version of LuaRocks to build, such as 3.1.2. If absent, LuaRocks
                                     will not be built.

      --pcre <pcre_ver>              Version of PCRE to build, such as 8.43. If absent, PCRE will
                                     not be build.

      --add-module <module_path>     Path to additional NGINX module to be built. This option can be
                                     repeated and will be passed to NGINX's configure in the order
                                     they were specified.

      --debug                        Disable compile-time optimizations and memory pooling for NGINX,
                                     LuaJIT and OpenSSL to help debugging.

  -j, --jobs                         Concurrency level to use when building.
                                     (Defaults to number of CPU cores available: 12)

      --work <work>                  The working directory to use while compiling.
                                     (Defaults to "work")

  -f, --force                        Build from scratch.
                                     WARNING: This permanently removes everything inside the <work> and <prefix> directories.

  -h, --help                         Show this message.

Optional environment variables:

The following environment variables are likely only utilized when building for the purposes of packaging Kong

  LUAROCKS_INSTALL                 Overrides the `./config --prefix` value (default is `<prefix>/luarocks`)

  LUAROCKS_DESTDIR                 Overrides the `make install DESTDIR` (default is `/`)

  OPENRESTY_INSTALL                Overrides the `./config --prefix` value (default is `--prefix/openresty)

  OPENRESTY_DESTDIR                Overrides the `make install DESTDIR` (default is `/`)

  OPENSSL_INSTALL                  Overrides the `./config --prefix` value (default is `--prefix/openssl)

  OPENRESTY_RPATH                  Overrides the `make install DESTDIR` (default is `/`)

```

# Caching
This script supports two level of caching: artifact caching and build caching
in order to speed up re-compilation time for various different scenarios.

By default, both artifact caching and build caching are enabled.

Artifact caching checks the installation directory inside `prefix`, if that
directory is found, then it is assumed that software has been built already
and no more work is done on it.

Build caching saves the source code directory of the software to be built.
Repeated run will simply call `make` and `make install` again which supports
incremental rebuild Make provides. This is especially useful when developing
on OpenResty or NGINX C code.

If caching is undesirable or dependency version changed,
you can disable both caching with the `--force` option.

# Special notes for macOS users
`openresty-build-tools` needs a few utilities from the GNU `coreutils` suite to
run properly on a Mac. It can be installed using [Homebrew](https://brew.sh)
easily:

```shell
$ brew install coreutils
```

# License

```
Copyright 2019 Kong Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
