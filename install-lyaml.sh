#!/bin/bash

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

/tmp/build/usr/local/bin/luarocks install lyaml $LYAML_VERSION \
    YAML_LIBDIR=/tmp/build/usr/local/kong/lib \
    YAML_INCDIR=/tmp/yaml-${LIBYAML_VERSION} \
    CFLAGS="-L/tmp/build/usr/local/kong/lib -Wl,-rpath,/usr/local/kong/lib -O2 -fPIC"

