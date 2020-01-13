#!/bin/bash

set -e
set -x

if [[ "$RESTY_IMAGE_BASE" == "src" ]]; then
  exit 0
fi

if [[ -z $HOST ]] || [[ -z $ADMIN_PORT ]] || [[ -z $PROXY_PORT ]]; then
  echo "Missing required arguments"
  exit 1
fi

USE_TTY="-t"
test -t 1 && USE_TTY="-it"

# XXX why only ubuntu?
if [[ "$RESTY_IMAGE_BASE" == "ubuntu" ]]; then
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "openresty -v" | grep -q ${RESTY_VERSION}
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "/usr/local/kong/bin/openssl version" | grep -q ${RESTY_OPENSSL_VERSION}
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "luarocks --version" | grep -q ${RESTY_LUAROCKS_VERSION}
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "luarocks config" | grep -q "/usr/local/openresty/luajit/bin/luajit"
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "luarocks config" | grep -q "/usr/local/openresty/luajit/include/luajit-2.1"
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "luarocks config" | grep -q "/usr/local/openresty/luajit/lib"
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "ldd /usr/local/openresty/bin//openresty" | grep -q "/usr/local/kong/lib/libssl.so.1.1"
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "ldd /usr/local/openresty/bin//openresty" | grep -q "/usr/local/kong/lib/libcrypto.so.1.1"
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "ldd /usr/local/openresty/bin//openresty" | grep -q "/usr/local/openresty/luajit/lib/libluajit-5.1.so.2"
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "openresty -V" | grep "/work/pcre-${RESTY_PCRE_VERSION}"
fi

# XXX why only bionic?
if [[ "$RESTY_IMAGE_TAG" == "bionic" ]]; then
    cp output/*.deb kong.deb
    docker run -d --rm --name systemd-ubuntu --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v $PWD:/src jrei/systemd-ubuntu
    docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "dpkg -i /src/kong.deb || true"
    docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "apt-get update"
    docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "apt-get install -f -y"
    docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl start kong"
    docker stop systemd-ubuntu
fi

docker run ${USE_TTY} --rm ${KONG_TEST_CONTAINER_NAME} /bin/sh -c "luarocks --version"
docker run ${USE_TTY} --rm ${KONG_TEST_CONTAINER_NAME} /bin/sh -c "luarocks install version"
docker run ${USE_TTY} --rm ${KONG_TEST_CONTAINER_NAME} /bin/sh -c "ls -la /usr/local/bin/go-pluginserver"

TEST_ADMIN_URI=https://$HOST:$ADMIN_PORT TEST_PROXY_URI=http://$HOST:$PROXY_PORT make -f Makefile run_tests
