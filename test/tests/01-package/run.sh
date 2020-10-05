set -x

docker run -d --name user-validation-tests --rm -e KONG_DATABASE=off -v $PWD:/src ${RESTY_IMAGE_BASE}:${RESTY_IMAGE_TAG} tail -f /dev/null

if [[ "$PACKAGE_TYPE" == "rpm" ]]; then
  cp $PACKAGE_LOCATION/*.rpm kong.rpm
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "yum install -y /src/kong.rpm"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "kong version"
fi

if [[ "$PACKAGE_TYPE" == "deb" ]]; then
  cp $PACKAGE_LOCATION/*.deb kong.deb
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "apt-get update"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "apt install --yes /src/kong.deb"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "kong version"
fi

if [[ "$RESTY_IMAGE_BASE" != "alpine" ]]; then

  # these files should have 'kong:kong' ownership
  files=(
    "/etc/kong/"
    "/usr/local/bin/json2lua"
    "/usr/local/bin/lapis"
    "/usr/local/bin/lua2json"
    "/usr/local/bin/luarocks"
    "/usr/local/bin/luarocks-admin"
    "/usr/local/etc/luarocks/"
    "/usr/local/kong/"
    "/usr/local/bin/kong"
    "/usr/local/lib/lua/"
    "/usr/local/lib/luarocks/"
    "/usr/local/openresty/"
    "/usr/local/share/lua/"
  )

  for file in "${files[@]}"; do
    # Check if the 'chown -R kong:kong' ownership changes worked
    docker exec ${USE_TTY} -e file=$file user-validation-tests /bin/bash -c '[ $(find $file -exec stat -c "%U:%G" {} \; | grep -vc "kong:kong") == "0" ]'

    # Check if the 'chmod g=u -R' permission changes worked
    docker exec ${USE_TTY} -e file=$file user-validation-tests /bin/bash -c '[ $(find $file -exec stat -c "%a" {} \; | grep -Evc "^(.)\1") == "0" ]'
  done

  # Check if 'useradd -U -m -s /bin/sh kong' worked
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "getent passwd kong"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "getent group kong"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "test -d /home/kong/"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "cat /etc/passwd | grep kong | grep -q /bin/sh"

  if [[ "$RESTY_IMAGE_BASE" == "amazonlinux" ]]; then
    # needed for `su`
    docker exec ${USE_TTY} user-validation-tests /bin/bash -c "yum install -y util-linux"

    # needed for `find`
    docker exec ${USE_TTY} user-validation-tests /bin/bash -c "yum install -y findutils"

    # needed for `ps`
    docker exec ${USE_TTY} user-validation-tests /bin/bash -c "yum install -y procps"
  fi

  if [[ "$PACKAGE_TYPE" == "deb" ]]; then
    # needed for `ps`
    docker exec ${USE_TTY} user-validation-tests /bin/bash -c "apt-get -y install procps"
  fi

  # We're capable of running as the kong user
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "su - kong -c 'KONG_DATABASE=off kong start'"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "su - kong -c 'KONG_DATABASE=off kong health'"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "ps aux | grep master | grep -v grep | awk '{print $1}' | grep -q kong"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "su - kong -c 'KONG_DATABASE=off kong restart'"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "su - kong -c 'KONG_DATABASE=off kong health'"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "ps aux | grep master | grep -v grep | awk '{print $1}' | grep -q kong"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "su - kong -c 'KONG_DATABASE=off kong stop'"

  # Default kong runs as root user
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "kong start"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "kong health"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "ps aux | grep nginx | grep -v worker | grep -v grep | grep -q root"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "kong restart"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "kong health"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "ps aux | grep nginx | grep -v worker | grep -v grep | grep -q root"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "kong stop"
fi
docker stop user-validation-tests

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

# TODO enable this test in other distros containing systemd
if [[ "$RESTY_IMAGE_TAG" == "bionic" ]]; then
  cp $PACKAGE_LOCATION/*.deb kong.deb
  docker run -d --rm --name systemd-ubuntu -e KONG_DATABASE=off --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v $PWD:/src jrei/systemd-ubuntu:18.04
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "apt-get update"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "apt install --yes /src/kong.deb"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "kong version"

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
