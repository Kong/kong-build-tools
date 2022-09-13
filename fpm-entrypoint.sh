#!/bin/bash

set -o errexit

cd /tmp/build

# ubuntu | debian | centos | amazonlinux | alpine | rhel
readonly DISTRO_NAME=${RESTY_IMAGE_BASE:-}

# typically this is a version number (e.g. "7" or "18.04"), but sometimes
# it is a label/nickname corresponding to that version instead (e.g. "bionic")
readonly DISTRO_VERSION=${RESTY_IMAGE_TAG:-}

# linux/amd64  => amd64
# linux/arm/v7 => arm
PLATFORM_ARCH=${TARGETPLATFORM#*/}
readonly PLATFORM_ARCH=${PLATFORM_ARCH%%/*}

# deb | rpm | apk
readonly PACKAGE_TYPE=${PACKAGE_TYPE:?PACKAGE_TYPE is undefined}

# Kong tag or Kong version
readonly PACKAGE_VERSION=${KONG_RELEASE_LABEL:-}

PACKAGE_NAME=${KONG_PACKAGE_NAME:-kong}
PACKAGE_CONFLICTS=${PACKAGE_CONFLICTS:-kong-enterprise-edition}
PACKAGE_PROVIDES=${PACKAGE_PROVIDES:-kong-community-edition}
PACKAGE_REPLACES=${PACKAGE_REPLACES:-kong-community-edition}


if [ "$PACKAGE_NAME" = "kong" ];
then
  PACKAGE_CONFLICTS=kong-enterprise-edition
  PACKAGE_CONFLICTS_2=kong-enterprise-edition-fips

  PACKAGE_REPLACES=kong-enterprise-edition
  PACKAGE_REPLACES_2=kong-enterprise-edition-fips

elif [ "$PACKAGE_NAME" = "kong-enterprise-edition" ]
then
  PACKAGE_CONFLICTS=kong-community-edition
  PACKAGE_CONFLICTS_2=kong-enterprise-edition-fips

  PACKAGE_REPLACES=kong-community-edition
  PACKAGE_REPLACES_2=kong-enterprise-edition-fips

elif [ "$PACKAGE_NAME" = "kong-enterprise-edition-fips" ] || [ "$SSL_PROVIDER" = "boringssl" ]
then
  PACKAGE_NAME=kong-enterprise-edition-fips
  PACKAGE_CONFLICTS=kong-community-edition
  PACKAGE_CONFLICTS_2=kong-enterprise-edition

  PACKAGE_REPLACES=kong-community-edition
  PACKAGE_REPLACES_2=kong-enterprise-edition
fi

OUTPUT_FILE_SUFFIX=""
FPM_PARAMS=()
if [ "$PACKAGE_TYPE" == "deb" ]; then
  FPM_PARAMS=(
    -d libpcre3
    -d perl
    -d zlib1g-dev
  )
  OUTPUT_FILE_SUFFIX=".${DISTRO_VERSION}"

elif [ "$PACKAGE_TYPE" == "rpm" ]; then
  FPM_PARAMS=(
    -d pcre
    -d perl
    -d perl-Time-HiRes
    -d zlib
    -d zlib-devel
  )
  OUTPUT_FILE_SUFFIX=".rhel${DISTRO_VERSION}"

  if [ "$DISTRO_VERSION" == "7" ]; then
    FPM_PARAMS+=(-d hostname)
  fi

  if [ "$DISTRO_NAME" == "amazonlinux" ]; then
    OUTPUT_FILE_SUFFIX=".aws"
    FPM_PARAMS+=(
      -d /usr/sbin/useradd
      -d /usr/sbin/groupadd
    )
  fi

  if [ "$DISTRO_NAME" == "centos" ]; then
    OUTPUT_FILE_SUFFIX=".el${DISTRO_VERSION}"
  fi
fi

OUTPUT_FILE_SUFFIX="${OUTPUT_FILE_SUFFIX}.${PLATFORM_ARCH}"

if [ "$PACKAGE_TYPE" == "apk" ]; then
  pushd /tmp/build
    mkdir /output
    tar -zcvf "/output/${PACKAGE_NAME}-${PACKAGE_VERSION}${OUTPUT_FILE_SUFFIX}.apk.tar.gz" usr etc
  popd

else
  fpm -f -s dir \
    -t "$PACKAGE_TYPE" \
    -m 'support@konghq.com' \
    -n "$PACKAGE_NAME" \
    -v "$PACKAGE_VERSION" \
    "${FPM_PARAMS[@]}" \
    --description 'Kong is a distributed gateway for APIs and Microservices, focused on high performance and reliability.' \
    --vendor 'Kong Inc.' \
    --license "ASL 2.0" \
    --conflicts "$PACKAGE_CONFLICTS" \
    --conflicts "$PACKAGE_CONFLICTS_2" \
    --provides "$PACKAGE_PROVIDES" \
    --replaces "$PACKAGE_REPLACES" \
    --replaces "$PACKAGE_REPLACES_2" \
    --after-install '/after-install.sh' \
    --url 'https://getkong.org/' usr etc lib \
  && mkdir /output/ \
  && mv kong*.* "/output/${PACKAGE_NAME}-${PACKAGE_VERSION}${OUTPUT_FILE_SUFFIX}.${PACKAGE_TYPE}"

  set -x

  if [ "$PACKAGE_TYPE" == "rpm" ] && [ ! -z "$PRIVATE_KEY_PASSPHRASE" ]; then
    apt-get update
    apt-get install -y expect
    mkdir -p ~/.gnupg/
    touch ~/.gnupg/gpg.conf
    echo use-agent >> ~/.gnupg/gpg.conf
    echo pinentry-mode loopback >> ~/.gnupg/gpg.conf
    echo allow-loopback-pinentry >> ~/.gnupg/gpg-agent.conf
    echo RELOADAGENT | gpg-connect-agent
    cp /.rpmmacros ~/
    gpg --batch --import /kong.private.asc
    /sign-rpm.exp "/output/${PACKAGE_NAME}-${PACKAGE_VERSION}${OUTPUT_FILE_SUFFIX}.${PACKAGE_TYPE}"
  fi
fi

