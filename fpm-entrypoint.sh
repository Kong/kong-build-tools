#!/bin/bash

set -o errexit

cd /tmp/build

if [ -z "$KONG_PACKAGE_NAME" ]
then
  KONG_PACKAGE_NAME=kong
fi

if [ -z "$PACKAGE_CONFLICTS" ]
then
  PACKAGE_CONFLICTS=kong-enterprise-edition
fi

if [ -z "$PACKAGE_PROVIDES" ]
then
  PACKAGE_PROVIDES=kong-community-edition
fi

if [ -z "$PACKAGE_REPLACES" ]
then
  PACKAGE_REPLACES=kong-community-edition
fi

if [ "$KONG_PACKAGE_NAME" = "kong" ];
then
  PACKAGE_CONFLICTS=kong-enterprise-edition
  PACKAGE_CONFLICTS_2=kong-enterprise-edition-fips

  PACKAGE_REPLACES=kong-enterprise-edition
  PACKAGE_REPLACES_2=kong-enterprise-edition-fips

elif [ "$KONG_PACKAGE_NAME" = "kong-enterprise-edition" ]
then
  PACKAGE_CONFLICTS=kong-community-edition
  PACKAGE_CONFLICTS_2=kong-enterprise-edition-fips

  PACKAGE_REPLACES=kong-community-edition
  PACKAGE_REPLACES_2=kong-enterprise-edition-fips

elif [ "$KONG_PACKAGE_NAME" = "kong-enterprise-edition-fips" ] || [ "$SSL_PROVIDER" = "boringssl" ]
then
  KONG_PACKAGE_NAME=kong-enterprise-edition-fips
  PACKAGE_CONFLICTS=kong-community-edition
  PACKAGE_CONFLICTS_2=kong-enterprise-edition

  PACKAGE_REPLACES=kong-community-edition
  PACKAGE_REPLACES_2=kong-enterprise-edition

fi

FPM_PARAMS=""
if [ "$PACKAGE_TYPE" == "deb" ]; then
  FPM_PARAMS="-d libpcre3 -d perl -d zlib1g-dev"
  OUTPUT_FILE_SUFFIX=".${RESTY_IMAGE_TAG}"
elif [ "$PACKAGE_TYPE" == "rpm" ]; then
  FPM_PARAMS="-d pcre -d perl -d perl-Time-HiRes -d zlib -d zlib-devel"
  OUTPUT_FILE_SUFFIX=".rhel${RESTY_IMAGE_TAG}"
  if [ "$RESTY_IMAGE_TAG" == "7" ]; then
    FPM_PARAMS="$FPM_PARAMS -d hostname"
  fi
  if [ "$RESTY_IMAGE_BASE" == "amazonlinux" ]; then
    OUTPUT_FILE_SUFFIX=".aws"
    FPM_PARAMS="$FPM_PARAMS -d /usr/sbin/useradd -d /usr/sbin/groupadd"
  fi
  if [ "$RESTY_IMAGE_BASE" == "centos" ]; then
    OUTPUT_FILE_SUFFIX=".el${RESTY_IMAGE_TAG}"
  fi
fi
OUTPUT_FILE_SUFFIX="${OUTPUT_FILE_SUFFIX}."$(echo ${TARGETPLATFORM} | awk -F "/" '{ print $2}')
ROCKSPEC_VERSION=`basename /tmp/build/build/usr/local/lib/luarocks/rocks/kong/*`

if [ "$PACKAGE_TYPE" == "apk" ]; then
  pushd /tmp/build
    mkdir /output
    tar -zcvf /output/${KONG_PACKAGE_NAME}-${KONG_RELEASE_LABEL}${OUTPUT_FILE_SUFFIX}.apk.tar.gz usr etc
  popd
else
  fpm -f -s dir \
    -t $PACKAGE_TYPE \
    -m 'support@konghq.com' \
    -n $KONG_PACKAGE_NAME \
    -v $KONG_RELEASE_LABEL \
    $FPM_PARAMS \
    --description 'Kong is a distributed gateway for APIs and Microservices, focused on high performance and reliability.' \
    --vendor 'Kong Inc.' \
    --license "ASL 2.0" \
    --conflicts $PACKAGE_CONFLICTS \
    --conflicts $PACKAGE_CONFLICTS_2 \
    --provides $PACKAGE_PROVIDES \
    --replaces $PACKAGE_REPLACES \
    --replaces $PACKAGE_REPLACES_2 \
    --after-install '/after-install.sh' \
    --url 'https://getkong.org/' usr etc lib \
  && mkdir /output/ \
  && mv kong*.* /output/${KONG_PACKAGE_NAME}-${KONG_RELEASE_LABEL}${OUTPUT_FILE_SUFFIX}.${PACKAGE_TYPE}
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
    /sign-rpm.exp /output/${KONG_PACKAGE_NAME}-${KONG_RELEASE_LABEL}${OUTPUT_FILE_SUFFIX}.${PACKAGE_TYPE}
  fi
fi

