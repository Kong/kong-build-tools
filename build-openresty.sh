#!/bin/bash

buffer=
if [ -n "$VERBOSE" ] && [[ "$VERBOSE" != 'false' ]]; then
  buffer=1
fi

if [ -n "$buffer" ]; then
  export PING_SLEEP=50s
  export WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
fi

mkdir -p /tmp/build/usr/local/openresty
mkdir -p /tmp/build/usr/local/kong/lib
mkdir -p /tmp/build/usr/local/kong
mkdir -p /tmp/build/
mkdir -p /work

if [ "$DEBUG" == 1 ]; then
  KONG_NGX_BUILD_ARGS="--debug"
fi

if [ -z "$KONG_NGINX_MODULE" ]; then
  KONG_NGINX_MODULE="master"
fi

if [ -z "$RESTY_LMDB" ]; then
  RESTY_LMDB=0
fi

if [ -z "$RESTY_WEBSOCKET" ]; then
  RESTY_WEBSOCKET=0
fi

if [ -z "$RESTY_EVENTS" ]; then
  RESTY_EVENTS=0
fi

if [ -z "$ATC_ROUTER" ]; then
  ATC_ROUTER=0
fi

if [ -z "$RESTY_BORINGSSL_VERSION" ]; then
  RESTY_BORINGSSL_VERSION=0
fi

if [ -z "$RESTY_OPENSSL_VERSION" ]; then
  RESTY_OPENSSL_VERSION=0
fi

if [ -z "$KONG_OPENSSL_VERSION" ]; then
  KONG_OPENSSL_VERSION=0
fi

if [ -n "$buffer" ]; then

  EDITION=$EDITION \
  ENABLE_KONG_LICENSING=$ENABLE_KONG_LICENSING \
  LUAROCKS_DESTDIR=/tmp/build \
  LUAROCKS_PREFIX=/usr/local \
  OPENRESTY_DESTDIR=/tmp/build \
  OPENRESTY_PATCHES=$OPENRESTY_PATCHES \
  OPENRESTY_PREFIX=/usr/local/openresty \
  OPENRESTY_RPATH=/usr/local/kong/lib \
  OPENSSL_DESTDIR=/tmp/build \
  OPENSSL_PREFIX=/usr/local/kong \
  /tmp/openresty-build-tools/kong-ngx-build \
  --atc-router $ATC_ROUTER \
  --boringssl $RESTY_BORINGSSL_VERSION \
  --kong-nginx-module $KONG_NGINX_MODULE \
  --kong-openssl $KONG_OPENSSL_VERSION \
  --luarocks $RESTY_LUAROCKS_VERSION \
  --openresty $RESTY_VERSION \
  --openssl $RESTY_OPENSSL_VERSION \
  --pcre $RESTY_PCRE_VERSION \
  --resty-events $RESTY_EVENTS \
  --resty-lmdb $RESTY_LMDB \
  --resty-websocket $RESTY_WEBSOCKET \
  --ssl-provider $SSL_PROVIDER \
  --work /work \
  -p /tmp/build/usr/local \
  $KONG_NGX_BUILD_ARGS \
  >>$BUILD_OUTPUT 2>&1

else

  EDITION=$EDITION \
  ENABLE_KONG_LICENSING=$ENABLE_KONG_LICENSING \
  LUAROCKS_DESTDIR=/tmp/build \
  LUAROCKS_PREFIX=/usr/local \
  OPENRESTY_DESTDIR=/tmp/build \
  OPENRESTY_PATCHES=$OPENRESTY_PATCHES \
  OPENRESTY_PREFIX=/usr/local/openresty \
  OPENRESTY_RPATH=/usr/local/kong/lib \
  OPENSSL_DESTDIR=/tmp/build \
  OPENSSL_PREFIX=/usr/local/kong \
  /tmp/openresty-build-tools/kong-ngx-build \
  --atc-router $ATC_ROUTER \
  --boringssl $RESTY_BORINGSSL_VERSION \
  --kong-nginx-module $KONG_NGINX_MODULE \
  --kong-openssl $KONG_OPENSSL_VERSION \
  --luarocks $RESTY_LUAROCKS_VERSION \
  --openresty $RESTY_VERSION \
  --openssl $RESTY_OPENSSL_VERSION \
  --pcre $RESTY_PCRE_VERSION \
  --resty-events $RESTY_EVENTS \
  --resty-lmdb $RESTY_LMDB \
  --resty-websocket $RESTY_WEBSOCKET \
  --ssl-provider $SSL_PROVIDER \
  --work /work \
  -p /tmp/build/usr/local \
  $KONG_NGX_BUILD_ARGS

fi

if [ -n "$buffer" ]; then
  # The build finished without returning an error so dump a tail of the output
  dump_output

  # nicely terminate the ping output loop
  kill $PING_LOOP_PID
fi
