#!/bin/bash

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

pushd /kong
  ROCKSPEC_VERSION=`basename $TMP/kong/kong-*.rockspec` \
    && ROCKSPEC_VERSION=${ROCKSPEC_VERSION%.*} \
    && ROCKSPEC_VERSION=${ROCKSPEC_VERSION#"kong-"}
    
  /tmp/build/usr/local/bin/luarocks make kong-${ROCKSPEC_VERSION}.rockspec \
    OPENSSL_INCDIR=/tmp/openssl/include \
    CRYPTO_INCDIR=/tmp/openssl/include \
    CRYPTO_LIBDIR=/tmp/openssl

  cp kong.conf.default /tmp/build/usr/local/lib/luarocks/rocks/kong/$ROCKSPEC_VERSION/kong.conf.default
popd

cp /kong/bin/kong /tmp/build/usr/local/bin/kong
sed -i.bak 's@#!/usr/bin/env resty@#!/usr/bin/env /usr/local/openresty/bin/resty@g' /tmp/build/usr/local/bin/kong && \
  rm /tmp/build/usr/local/bin/kong.bak

cp -R /tmp/build/* /output/build/
chown -R 1000:1000 /output/build/*
