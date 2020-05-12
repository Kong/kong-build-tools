set -x

# openresty
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "/usr/local/openresty/bin/openresty -v 2>&1 | grep -q ${RESTY_VERSION}"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ldd /usr/local/openresty/bin/openresty | grep -q /usr/local/kong/lib/libssl.so.1.1"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ldd /usr/local/openresty/bin/openresty | grep -q /usr/local/kong/lib/libcrypto.so.1.1"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ldd /usr/local/openresty/bin/openresty | grep -q /usr/local/openresty/luajit/lib/libluajit-5.1.so.2"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "/usr/local/openresty/bin/openresty -V 2>&1 | grep /work/pcre-${RESTY_PCRE_VERSION}"

# luarocks
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "luarocks --version | grep -q ${RESTY_LUAROCKS_VERSION}"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "luarocks config | grep -q /usr/local/openresty/luajit/bin/luajit"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "luarocks config | grep -q /usr/local/openresty/luajit/include/luajit-2.1"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "luarocks config | grep -q /usr/local/openresty/luajit/lib"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "luarocks install version"

# kong binaries
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "/usr/local/kong/bin/openssl version | grep -q ${RESTY_OPENSSL_VERSION}"
docker run ${USE_TTY} --user=root --rm ${DOCKER_GO_BUILDER} /bin/sh -c "ls -la /usr/local/bin/go-pluginserver"

# TODO enable this test in other distros containing systemd
if [[ "$RESTY_IMAGE_TAG" == "bionic" ]]; then
  cp $PACKAGE_LOCATION/*.deb kong.deb
  docker run -d --rm --name systemd-ubuntu -e KONG_DATABASE=off --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v $PWD:/src jrei/systemd-ubuntu
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "apt-get update"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "dpkg -i /src/kong.deb || true"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "apt-get install -f -y"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "test -f /etc/kong/kong.logrotate"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "mkdir -p /etc/systemd/system/kong.service.d/"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "cat <<\EOD > /etc/systemd/system/kong.service.d/override.conf
[Service]
Environment=KONG_DATABASE=off
EOD"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl daemon-reload"
  sleep 5
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl start kong"
  sleep 5
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl reload kong"
  sleep 5
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl restart kong"
  sleep 5
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl stop kong"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "dpkg --remove $KONG_PACKAGE_NAME"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "! test -f /lib/systemd/system/kong.service"
  docker stop systemd-ubuntu
  rm kong.deb
fi
