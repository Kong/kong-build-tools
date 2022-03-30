#!/bin/bash

set -e
set -x

ROCKS_CONFIG=$(mktemp)
echo "
rocks_trees = {
   { name = [[system]], root = [[/tmp/build/usr/local]] }
}
" > $ROCKS_CONFIG

cp -R /tmp/build/* /

export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
export LUAROCKS_CONFIG=$ROCKS_CONFIG
export LUA_PATH="/usr/local/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/luajit-2.1.0-beta3/?.lua;;"
export PATH=$PATH:/usr/local/openresty/luajit/bin

/usr/local/bin/luarocks --version
/usr/local/kong/bin/openssl version
/usr/local/openresty/bin/openresty -v

if test -f /root/id_rsa; then
  mkdir -p /root/.ssh
  mv /root/id_rsa /root/.ssh/id_rsa
  chmod 700 /root/.ssh/id_rsa
  ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts
fi

pushd /kong
  ROCKSPEC_VERSION=`basename /kong/kong-*.rockspec` \
    && ROCKSPEC_VERSION=${ROCKSPEC_VERSION%.*} \
    && ROCKSPEC_VERSION=${ROCKSPEC_VERSION#"kong-"}

  mkdir -p /tmp/plugin
  
  luarocks purge --tree=/tmp/build/usr/local --old-versions || true
  /usr/local/bin/luarocks make kong-${ROCKSPEC_VERSION}.rockspec \
    CRYPTO_DIR=/usr/local/kong \
    OPENSSL_DIR=/usr/local/kong \
    YAML_LIBDIR=/tmp/build/usr/local/kong/lib \
    YAML_INCDIR=/tmp/yaml \
    CFLAGS="-L/tmp/build/usr/local/kong/lib -Wl,-rpath,/usr/local/kong/lib -O2 -fPIC"
  
  pushd /distribution
    ./post-*.sh
  popd

  mkdir -p /tmp/build/etc/kong
  cp kong.conf.default /tmp/build/usr/local/lib/luarocks/rock*/kong/$ROCKSPEC_VERSION/
  cp kong.conf.default /tmp/build/etc/kong/kong.conf.default
  cp kong/pluginsocket.proto /tmp/build/usr/local/kong/lib

  curl -fsSLo /tmp/protoc.zip https://github.com/protocolbuffers/protobuf/releases/download/v3.19.0/protoc-3.19.0-linux-x86_64.zip
  unzip -o /tmp/protoc.zip -d /tmp/protoc 'include/*'
  cp -r /tmp/protoc/include/google /tmp/build/usr/local/kong/lib
popd

cp /kong/COPYRIGHT /tmp/build/usr/local/kong/
cp /kong/bin/kong /tmp/build/usr/local/bin/kong
sed -i 's/resty/\/usr\/local\/openresty\/bin\/resty/' /tmp/build/usr/local/bin/kong
grep -l -I -r '\/tmp\/build' /tmp/build/
sed -i 's/\/tmp\/build//' `grep -l -I -r '\/tmp\/build' /tmp/build/`

chown -R 1000:1000 /tmp/build/*
