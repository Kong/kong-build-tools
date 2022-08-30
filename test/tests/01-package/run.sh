set -x

if \
  [ "$RESTY_IMAGE_BASE" == 'rhel' ] || \
  [[ "$RESTY_IMAGE_BASE" == *'/ubi'* ]] || \
  [[ "$RESTY_IMAGE_BASE" == *'redhat'* ]]
then
  major="${RESTY_IMAGE_TAG%%.*}"
  IMAGE_BASE="registry.access.redhat.com/ubi${major}/ubi"
else
  IMAGE_BASE="${RESTY_IMAGE_BASE}:${RESTY_IMAGE_TAG}"
fi

# docker system call amd64 "x86_64" and arm64 "aarch64"
DOCKER_SYSTEM_ARCHITECTURE="$(docker system info --format '{{.Architecture}}')"

# fall back on uname -m
DOCKER_SYSTEM_ARCHITECTURE="${DOCKER_SYSTEM_ARCHITECTURE:-$(
  uname -m
)}"

case "_${DOCKER_SYSTEM_ARCHITECTURE}" in
  _aarch64|_arm64)
    BASE_DOCKER_PLATFORM='linux/arm64/v8'
    ;;
  _x86_64|_amd64)
    BASE_DOCKER_PLATFORM='linux/amd64'
    ;;
  _|_*)
    # docker run allows this to be an empty string (aka default platform)
    BASE_DOCKER_PLATFORM=''
    ;;
esac

docker run \
  -d \
  --name user-validation-tests \
  --rm \
  --platform "$BASE_DOCKER_PLATFORM" \
  -e KONG_DATABASE=off \
  -v "${PWD}:/src" \
  "$IMAGE_BASE" \
  tail -f /dev/null
if [[ "$PACKAGE_TYPE" == "rpm" ]]; then
  cp $PACKAGE_LOCATION/*amd64.rpm kong.rpm
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "yum install -y /src/kong.rpm procps"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "kong version"
# Tests disabled until CSRE-467 is resolved
#  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "rpm --import https://download.konghq.com/gateway-2.x-rhel-8/repodata/repomd.xml.key"
#  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "rpm --checksig /src/kong.rpm"
fi

if [[ "$PACKAGE_TYPE" == "deb" ]]; then
  cp $PACKAGE_LOCATION/*amd64.deb kong.deb
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "apt-get update"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "apt-get install -y perl-base zlib1g-dev"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "dpkg -i /src/kong.deb || apt install --fix-broken -y"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "kong version"
fi

if [[ "$RESTY_IMAGE_BASE" != "alpine" ]]; then
  # These files should have 'kong:kong' ownership
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

  if \
    [[ "$RESTY_IMAGE_BASE" == "amazonlinux" ]] || \
    [ "$RESTY_IMAGE_BASE" == 'rhel' ] || \
    [[ "$RESTY_IMAGE_BASE" == *'/ubi'* ]] || \
    [[ "$RESTY_IMAGE_BASE" == *'redhat'* ]] \
  ; then
    # Needed to run `su`
    docker exec ${USE_TTY} user-validation-tests /bin/bash -c "yum install -y util-linux"

    # Needed to run `find`
    docker exec ${USE_TTY} user-validation-tests /bin/bash -c "yum install -y findutils"

    # Needed to run `ps`
    docker exec ${USE_TTY} user-validation-tests /bin/bash -c "yum install -y procps"
  fi

  if [[ "$PACKAGE_TYPE" == "deb" ]]; then
    # Needed to run `ps`
    docker exec ${USE_TTY} user-validation-tests /bin/bash -c "apt-get -y install procps"
  fi

  KONG_OPTS=
  if [ "$SSL_PROVIDER" = "boringssl" ]; then
    KONG_OPTS="KONG_FIPS=on"
    KONG_PACKAGE_NAME="kong-enterprise-edition-fips"
  fi

  # We're capable of running as the kong user
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "su - kong -c 'KONG_DATABASE=off $KONG_OPTS kong start'"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "su - kong -c 'KONG_DATABASE=off $KONG_OPTS kong health'"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "ps aux | grep master | grep -v grep | awk '{print $1}' | grep -q kong"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "su - kong -c 'KONG_DATABASE=off $KONG_OPTS kong restart'"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "su - kong -c 'KONG_DATABASE=off $KONG_OPTS kong health'"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "ps aux | grep master | grep -v grep | awk '{print $1}' | grep -q kong"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "su - kong -c 'KONG_DATABASE=off $KONG_OPTS kong stop'"

  # Default kong runs as root user
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "$KONG_OPTS kong start"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "$KONG_OPTS kong health"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "ps aux | grep nginx | grep -v worker | grep -v grep | grep -q root"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "$KONG_OPTS kong restart"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "$KONG_OPTS kong health"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "ps aux | grep nginx | grep -v worker | grep -v grep | grep -q root"
  docker exec ${USE_TTY} user-validation-tests /bin/bash -c "$KONG_OPTS kong stop"
fi
docker stop user-validation-tests

# openresty
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "/usr/local/openresty/bin/openresty -v 2>&1 | grep -q ${RESTY_VERSION}"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ldd /usr/local/openresty/bin/openresty | grep -q '/usr/local/kong/lib/libssl.so*'"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ldd /usr/local/openresty/bin/openresty | grep -q '/usr/local/kong/lib/libcrypto.so*'"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ldd /usr/local/openresty/bin/openresty | grep -q /usr/local/openresty/luajit/lib/libluajit-5.1.so.2"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "/usr/local/openresty/bin/openresty -V 2>&1 | grep /work/pcre-${RESTY_PCRE_VERSION}"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "/usr/local/openresty/bin/resty -e 'print(jit.version)' | grep -q 'LuaJIT[[:space:]][[:digit:]]\+.[[:digit:]]\+.[[:digit:]]\+-[[:digit:]]\{8\}'"

if [ "$SSL_PROVIDER" = "boringssl" ]; then
  docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "/usr/local/openresty/bin/openresty -V 2>&1 | grep 'running with BoringSSL'"
fi

# lua-resty-websocket library (sourced from OpenResty or Kong/lua-resty-websocket)
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ls -l /usr/local/openresty/lualib/resty/websocket/*.lua"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "grep _VERSION /usr/local/openresty/lualib/resty/websocket/*.lua"

# kong shipped files
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ls -l /etc/kong/kong.conf.default"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ls -l /etc/kong/kong*.logrotate"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ls -l /usr/local/kong/include/kong/pluginsocket.proto"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ls -l /usr/local/kong/include/wrpc/wrpc.proto"
docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "ls -l /usr/local/kong/include/google/protobuf/*.proto"

if [[ "$EDITION" == "enterprise" ]]; then
  docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /usr/local/openresty/bin/resty -e 'require("ffi").load "passwdqc"'
  docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /usr/local/openresty/bin/resty -e 'require("ffi").load "jq"'
  #docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} openapi2kong 2>&1 | head -1 | grep 'missing required parameter:'
  docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} ls -l /usr/local/kong/include/kong/pluginsocket.proto
  docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/bash -c "ls -l /usr/local/kong/include/google/protobuf/*.proto"
fi

# kong binaries

if [ "$SSL_PROVIDER" = "openssl" ]; then
  docker run ${USE_TTY} --user=root --rm ${KONG_TEST_IMAGE_NAME} /bin/sh -c "/usr/local/kong/bin/openssl version | grep -q ${RESTY_OPENSSL_VERSION}"
fi

# TODO enable this test in other distros containing systemd
if [[ "$RESTY_IMAGE_BASE" == "ubuntu" ]] && [ -z "${DARWIN:-}" ]; then
  cp $PACKAGE_LOCATION/*amd64.deb kong.deb
  docker run -d --rm --name systemd-ubuntu -e KONG_DATABASE=off --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v $PWD:/src jrei/systemd-ubuntu:$RESTY_IMAGE_TAG
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "apt-get clean"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "apt-get update"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "apt install --yes /src/kong.deb"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "kong version"

  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "test -f /etc/kong/kong*.logrotate"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "mkdir -p /etc/systemd/system/kong.service.d/"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "cat <<\EOD > /etc/systemd/system/kong.service.d/override.conf
[Service]
Environment=KONG_DATABASE=off
EOD"
  if [ "$SSL_PROVIDER" = "boringssl" ]; then
    docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "cat <<\EOD >> /etc/systemd/system/kong.service.d/override.conf
[Service]
Environment=$KONG_OPTS
EOD"
  fi
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl daemon-reload"
  sleep 5
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl start kong"
  sleep 5
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl --no-pager status kong"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl reload kong"
  sleep 5
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl --no-pager status kong"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl restart kong"
  sleep 5
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl --no-pager status kong"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl stop kong"
  sleep 5
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl --no-pager status kong || true" # systemctl will exit with 3 if unit is not active
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "dpkg --remove $KONG_PACKAGE_NAME"
  docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "! test -f /lib/systemd/system/kong.service"
  docker stop systemd-ubuntu
  rm kong.deb
fi
