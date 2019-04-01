#!/bin/bash

set -e

ROCKS_CONFIG=$(mktemp)
echo "
rocks_trees = {
   { name = [[system]], root = [[/tmp/build/usr/local]] }
}
" > $ROCKS_CONFIG

export LUAROCKS_CONFIG=$ROCKS_CONFIG
export LUA_PATH="/tmp/build/usr/local/share/lua/5.1/?.lua;${BUILD}/usr/local/openresty/luajit/share/luajit-2.1.0-beta3/?.lua;;"
export PATH=$PATH:/tmp/build/usr/local/openresty/luajit/bin

pushd /tmp/openssl
  make install_sw
popd

pushd /tmp/yaml-${LIBYAML_VERSION}
  make install
popd

pushd /kong
  ROCKSPEC_VERSION=`basename /kong/kong-*.rockspec` \
    && ROCKSPEC_VERSION=${ROCKSPEC_VERSION%.*} \
    && ROCKSPEC_VERSION=${ROCKSPEC_VERSION#"kong-"}

  /tmp/build/usr/local/bin/luarocks install lyaml $LYAML_VERSION \
    YAML_LIBDIR=/tmp/build/usr/local/kong/lib \
    YAML_INCDIR=/tmp/yaml-${LIBYAML_VERSION} \
    CFLAGS="-L/tmp/build/usr/local/kong/lib -Wl,-rpath,/usr/local/kong/lib -O2 -fPIC"

  /tmp/build/usr/local/bin/luarocks make kong-${ROCKSPEC_VERSION}.rockspec \
    OPENSSL_LIBDIR=/tmp/openssl \
    OPENSSL_DIR=/tmp/openssl

  mkdir -p /tmp/build/etc/kong
  cp kong.conf.default /tmp/build/usr/local/lib/luarocks/rocks/kong/$ROCKSPEC_VERSION/kong.conf.default
  cp kong.conf.default /tmp/build/etc/kong/kong.conf.default
popd

cp /kong/COPYRIGHT /tmp/build/usr/local/kong/
cp /kong/bin/kong /tmp/build/usr/local/bin/kong
sed -i.bak 's@#!/usr/bin/env resty@#!/usr/bin/env /usr/local/openresty/bin/resty@g' /tmp/build/usr/local/bin/kong && \
  rm /tmp/build/usr/local/bin/kong.bak

cp -R /tmp/build/* /output/build/
chown -R 1000:1000 /output/build/*
