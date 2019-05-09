#!/bin/bash

set -e
set -x

ROCKS_CONFIG=$(mktemp)
echo "
rocks_trees = {
   { name = [[system]], root = [[/tmp/build/usr/local]] }
}
" > $ROCKS_CONFIG

export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
export LUAROCKS_CONFIG=$ROCKS_CONFIG
export LUA_PATH="/tmp/build/usr/local/share/lua/5.1/?.lua;/tmp/build/usr/local/openresty/luajit/share/luajit-2.1.0-beta3/?.lua;;"
export PATH=$PATH:/tmp/build/usr/local/openresty/luajit/bin

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
  
  grep git@github.com .requirements | while read -r line ; do
    rm -rf /tmp/plugin || true
    echo "Processing $line"
    repo_url=$(echo $line | cut -d " " -f1)
    echo $repo_url
    version=$(echo $line | cut -d " " -f2)
    git clone --branch $version --recursive $repo_url /tmp/plugin/
    cd /tmp/plugin/
    /tmp/build/usr/local/bin/luarocks make kong-*.rockspec OPENSSL_LIBDIR=/tmp/openssl OPENSSL_DIR=/tmp/openssl
    cd /kong
  done
  
  grep https://api.github.com .requirements | while read -r line ; do
    rm -rf /tmp/plugin || true
    rm -rf /tmp/release.tar.gz || true
    echo "Processing $line"
    github_url=$(echo $line | cut -d " " -f1)
    asset_url=`curl $github_url?access_token=$GITHUB_ACCESSTOKEN | grep \/assets\/ | cut -d '"' -f 4`
    curl -L -o /tmp/release.tar.gz -H 'Accept:application/octet-stream' $asset_url?access_token=$GITHUB_ACCESSTOKEN
    tar -xzvf /tmp/release.tar.gz --directory /tmp/plugin
    directory=$(echo $line | cut -d " " -f2)
    mv /tmp/plugin/dist /tmp/build/usr/local/kong/$directory
  done

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

sed -i 's/\/tmp\/build//' `find /tmp/build/usr/local/bin/ -maxdepth 1 -type f`
sed -i 's/\/tmp\/build//' `find /tmp/build/usr/local/share/lua/5.1/luarocks/ -maxdepth 1 -type f`

cp -R /tmp/build/* /output/build/
chown -R 1000:1000 /output/*
