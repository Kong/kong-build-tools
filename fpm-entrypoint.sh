#!/bin/bash

set -e

cd /tmp/build

FPM_PARAMS=""
if [ "$RESTY_IMAGE_BASE" == "ubuntu" ] || [ "$RESTY_IMAGE_BASE" == "debian" ]; then
  PACKAGE_TYPE="deb"
  FPM_PARAMS="-d libpcre3 -d perl"
  OUTPUT_FILE_SUFFIX=".${RESTY_IMAGE_TAG}.all"
elif [ "$RESTY_IMAGE_BASE" == "centos" ]; then
  PACKAGE_TYPE="rpm"
  FPM_PARAMS="-d pcre -d perl -d perl-Time-HiRes"
  OUTPUT_FILE_SUFFIX=".el${RESTY_IMAGE_TAG}.noarch"
elif [ "$RESTY_IMAGE_BASE" == "rhel" ]; then
  PACKAGE_TYPE="rpm"
  FPM_PARAMS="-d pcre -d perl -d perl-Time-HiRes"
  OUTPUT_FILE_SUFFIX=".rhel${RESTY_IMAGE_TAG}.noarch"
  if [ "$RESTY_IMAGE_TAG" == "7" ]; then
    FPM_PARAMS="$FPM_PARAMS -d hostname"
  fi
elif [ "$RESTY_IMAGE_BASE" == "amazonlinux" ]; then
  PACKAGE_TYPE="rpm"
  FPM_PARAMS="-d pcre -d perl -d perl-Time-HiRes"
  OUTPUT_FILE_SUFFIX=".aws"
fi

ROCKSPEC_VERSION=`basename /tmp/build/build/usr/local/lib/luarocks/rocks/kong/*`

if [ "$RESTY_IMAGE_BASE" == "alpine" ]; then
  pushd /tmp/build
    tar -zcvf /output/${KONG_PACKAGE_NAME}-${KONG_VERSION}${OUTPUT_FILE_SUFFIX}.apk.tar.gz usr etc
  popd
else
  fpm -a all -f -s dir \
    -t $PACKAGE_TYPE \
    -m 'support@konghq.com' \
    -n $KONG_PACKAGE_NAME \
    -v $KONG_VERSION \
    $FPM_PARAMS \
    --conflicts $KONG_CONFLICTS \
    --description 'Kong is a distributed gateway for APIs and Microservices, focused on high performance and reliability.' \
    --vendor 'Kong Inc.' \
    --license "$KONG_LICENSE" \
    --provides 'kong-community-edition' \
    --url 'https://getkong.org/' usr etc \
  && mv kong*.* /output/${KONG_PACKAGE_NAME}-${KONG_VERSION}${OUTPUT_FILE_SUFFIX}.${PACKAGE_TYPE}
fi

