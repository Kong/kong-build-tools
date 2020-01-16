# XXX why only ubuntu?
if [[ "$RESTY_IMAGE_BASE" == "ubuntu" ]]; then
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "openresty -v 2>&1 | grep -q ${RESTY_VERSION}"
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "/usr/local/kong/bin/openssl version | grep -q ${RESTY_OPENSSL_VERSION}"
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "luarocks --version | grep -q ${RESTY_LUAROCKS_VERSION}"
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "luarocks config | grep -q /usr/local/openresty/luajit/bin/luajit"
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "luarocks config | grep -q /usr/local/openresty/luajit/include/luajit-2.1"
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "luarocks config | grep -q /usr/local/openresty/luajit/lib"
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "ldd /usr/local/openresty/bin/openresty | grep -q /usr/local/kong/lib/libssl.so.1.1"
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "ldd /usr/local/openresty/bin/openresty | grep -q /usr/local/kong/lib/libcrypto.so.1.1"
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "ldd /usr/local/openresty/bin/openresty | grep -q /usr/local/openresty/luajit/lib/libluajit-5.1.so.2"
    docker run ${USE_TTY} --rm kong/kong-build-tools:test /bin/bash -c "openresty -V 2>&1 | grep /work/pcre-${RESTY_PCRE_VERSION}"
fi

# XXX why only bionic?
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

docker run ${USE_TTY} --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "luarocks --version"
docker run ${USE_TTY} --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "luarocks install version"
docker run ${USE_TTY} --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ls -la /usr/local/bin/go-pluginserver"

