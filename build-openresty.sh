#!/bin/bash

set -x

# If an error occurs, run our error handler to output a tail of the build

mkdir -p /tmp/build/usr/local/openresty
mkdir -p /tmp/build/usr/local/kong/lib
mkdir -p /tmp/build/usr/local/kong
mkdir -p /tmp/build/
mkdir -p /work

if [ "$DEBUG" == 1 ]
then
  KONG_NGX_BUILD_ARGS="--debug"
fi

if [ -z "$KONG_NGINX_MODULE" ]
then
  KONG_NGINX_MODULE="master"
fi

if [ -z "$RESTY_LMDB" ]
then
  RESTY_LMDB=0
fi

if [ -z "$RESTY_WEBSOCKET" ]
then
  RESTY_WEBSOCKET=0
fi

if [ -z "$RESTY_EVENTS" ]
then
  RESTY_EVENTS=0
fi

if [ -z "$ATC_ROUTER" ]
then
  ATC_ROUTER=0
fi

if [ -z "$RESTY_BORINGSSL_VERSION" ]
then
  RESTY_BORINGSSL_VERSION=0
fi

if [ -z "$RESTY_OPENSSL_VERSION" ]
then
  RESTY_OPENSSL_VERSION=0
fi

LUAROCKS_PREFIX=/usr/local \
LUAROCKS_DESTDIR=/tmp/build \
OPENRESTY_PREFIX=/usr/local/openresty \
OPENRESTY_DESTDIR=/tmp/build \
OPENSSL_PREFIX=/usr/local/kong \
OPENSSL_DESTDIR=/tmp/build \
OPENRESTY_RPATH=/usr/local/kong/lib \
OPENRESTY_PATCHES=$OPENRESTY_PATCHES \
EDITION=$EDITION \
ENABLE_KONG_LICENSING=$ENABLE_KONG_LICENSING \
/tmp/openresty-build-tools/kong-ngx-build -p /tmp/build/usr/local \
--openresty $RESTY_VERSION \
--openssl $RESTY_OPENSSL_VERSION \
--boringssl $RESTY_BORINGSSL_VERSION \
--ssl-provider $SSL_PROVIDER \
--resty-lmdb $RESTY_LMDB \
--resty-websocket $RESTY_WEBSOCKET \
--resty-events $RESTY_EVENTS \
--atc-router $ATC_ROUTER \
--luarocks $RESTY_LUAROCKS_VERSION \
--kong-nginx-module $KONG_NGINX_MODULE \
--pcre $RESTY_PCRE_VERSION \
--work /work $KONG_NGX_BUILD_ARGS
