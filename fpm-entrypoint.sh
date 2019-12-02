#!/bin/bash

set -o errexit

cd /tmp/build

FPM_PARAMS=""
if [ "$RESTY_IMAGE_BASE" == "ubuntu" ] || [ "$RESTY_IMAGE_BASE" == "debian" ]; then
  PACKAGE_TYPE="deb"
  FPM_PARAMS="-d libpcre3 -d perl"
  OUTPUT_FILE_SUFFIX=".${RESTY_IMAGE_TAG}"
elif [ "$RESTY_IMAGE_BASE" == "centos" ]; then
  PACKAGE_TYPE="rpm"
  FPM_PARAMS="-d pcre -d perl -d perl-Time-HiRes"
  OUTPUT_FILE_SUFFIX=".el${RESTY_IMAGE_TAG}"
elif [ "$RESTY_IMAGE_BASE" == "rhel" ]; then
  PACKAGE_TYPE="rpm"
  FPM_PARAMS="-d pcre -d perl -d perl-Time-HiRes"
  OUTPUT_FILE_SUFFIX=".rhel${RESTY_IMAGE_TAG}"
  if [ "$RESTY_IMAGE_TAG" == "7" ]; then
    FPM_PARAMS="$FPM_PARAMS -d hostname"
  fi
elif [ "$RESTY_IMAGE_BASE" == "amazonlinux" ]; then
  PACKAGE_TYPE="rpm"
  FPM_PARAMS="-d pcre -d perl -d perl-Time-HiRes"
  OUTPUT_FILE_SUFFIX=".aws"
fi
OUTPUT_FILE_SUFFIX="${OUTPUT_FILE_SUFFIX}."$(echo ${BUILDPLATFORM} | awk -F "/" '{ print $2}')

ROCKSPEC_VERSION=`basename /tmp/build/build/usr/local/lib/luarocks/rocks/kong/*`

if [ "$RESTY_IMAGE_BASE" == "alpine" ]; then
  pushd /tmp/build
    mkdir /output
    tar -zcvf /output/${KONG_PACKAGE_NAME}-${KONG_VERSION}${OUTPUT_FILE_SUFFIX}.apk.tar.gz usr etc
  popd
else
  fpm -f -s dir \
    -t $PACKAGE_TYPE \
    -m 'support@konghq.com' \
    -n $KONG_PACKAGE_NAME \
    -v $KONG_VERSION \
    $FPM_PARAMS \
    --conflicts $KONG_CONFLICTS \
    --description 'Kong is a distributed gateway for APIs and Microservices, focused on high performance and reliability.' \
    --vendor 'Kong Inc.' \
    --license "ASL 2.0" \
    --provides 'kong-community-edition' \
    --after-install '/after-install.sh' \
    --url 'https://getkong.org/' usr etc lib \
  && mkdir /output/ \
  && mv kong*.* /output/${KONG_PACKAGE_NAME}-${KONG_VERSION}${OUTPUT_FILE_SUFFIX}.${PACKAGE_TYPE}
  if [ "$PACKAGE_TYPE" == "rpm" ] && [ ! -z "$PRIVATE_KEY_PASSPHRASE" ]; then
    gpg --import /kong.private.asc
    echo "$PRIVATE_KEY_PASSPHRASE" | rpm --addsign /output/${KONG_PACKAGE_NAME}-${KONG_VERSION}${OUTPUT_FILE_SUFFIX}.${PACKAGE_TYPE} > /dev/null 2>&1
  fi
fi

