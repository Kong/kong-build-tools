#!/bin/bash
set -e

export KONG_NGINX_DAEMON=off

if [[ "$1" == "kong" ]]; then
  PREFIX=${KONG_PREFIX:=/usr/local/kong}
  mkdir -p $PREFIX

  if [[ "$2" == "docker-start" ]]; then
    kong prepare -p $PREFIX
    chown -R kong $PREFIX
    
    chmod o+w /proc/self/fd/1
    chmod o+w /proc/self/fd/2
    
    setcap cap_net_raw=+ep /usr/local/openresty/nginx/sbin/nginx

    exec su-exec kong /usr/local/openresty/nginx/sbin/nginx \
      -p $PREFIX \
      -c nginx.conf
  fi
fi

exec "$@"
