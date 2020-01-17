
# openresty
docker run ${USE_TTY} --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "/usr/local/openresty/bin/openresty -v 2>&1 | grep -q ${RESTY_VERSION}"
docker run ${USE_TTY} --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ldd /usr/local/openresty/bin/openresty | grep -q /usr/local/kong/lib/libssl.so.1.1"
docker run ${USE_TTY} --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ldd /usr/local/openresty/bin/openresty | grep -q /usr/local/kong/lib/libcrypto.so.1.1"
docker run ${USE_TTY} --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ldd /usr/local/openresty/bin/openresty | grep -q /usr/local/openresty/luajit/lib/libluajit-5.1.so.2"
docker run ${USE_TTY} --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "/usr/local/openresty/bin/openresty -V 2>&1 | grep /work/pcre-${RESTY_PCRE_VERSION}"

# luarocks
docker run ${USE_TTY} --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "luarocks --version | grep -q ${RESTY_LUAROCKS_VERSION}"
docker run ${USE_TTY} --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "luarocks config | grep -q /usr/local/openresty/luajit/bin/luajit"
docker run ${USE_TTY} --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "luarocks config | grep -q /usr/local/openresty/luajit/include/luajit-2.1"
docker run ${USE_TTY} --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "luarocks config | grep -q /usr/local/openresty/luajit/lib"
docker run ${USE_TTY} --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "luarocks install version"

# kong binaries
docker run ${USE_TTY} --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "/usr/local/kong/bin/openssl version | grep -q ${RESTY_OPENSSL_VERSION}"
docker run ${USE_TTY} --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ls -la /usr/local/bin/go-pluginserver"

# TODO enable this test in other distros containing systemd
if [[ "$RESTY_IMAGE_TAG" == "bionic" ]]; then
  cp $PACKAGE_LOCATION/*.deb kong.deb
  docker run -d --rm --name systemd-ubuntu --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v $PWD:/src jrei/systemd-ubuntu
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "dpkg -i /src/kong.deb || true"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "apt-get update"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "apt-get install -f -y"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl start kong"
  docker stop systemd-ubuntu
  rm kong.deb
fi
