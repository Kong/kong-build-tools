#!/bin/bash

export PING_SLEEP=50s
export WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export BUILD_OUTPUT=$WORKDIR/build.out

touch $BUILD_OUTPUT

dump_output() {
   echo Tailing the last 500 lines of output:
   cat $BUILD_OUTPUT
}
error_handler() {
  echo ERROR: An error was encountered with the build.
  dump_output
  exit 1
}
# If an error occurs, run our error handler to output a tail of the build
trap 'error_handler' ERR

bash -c "while true; do echo \$(date) - building ...; sleep $PING_SLEEP; done" &
PING_LOOP_PID=$!

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
--work /work $KONG_NGX_BUILD_ARGS >> $BUILD_OUTPUT 2>&1


# The build finished without returning an error so dump a tail of the output
dump_output

# nicely terminate the ping output loop
kill $PING_LOOP_PID
