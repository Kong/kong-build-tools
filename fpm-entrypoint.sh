#!/bin/bash

cd /tmp/build

FPM_PARAMS=""
if [ "$RESTY_IMAGE_BASE" == "ubuntu" ]; then
  PACKAGE_TYPE="deb"
  FPM_PARAMS="-d openssl -d libpcre3 -d perl"
  OUTPUT_FILE_SUFFIX=".${RESTY_IMAGE_TAG}.all"
elif [ "$RESTY_IMAGE_BASE" == "centos" ]; then
  PACKAGE_TYPE="rpm"
  FPM_PARAMS="-d pcre -d perl -d perl-Time-HiRes -d openssl"
  OUTPUT_FILE_SUFFIX=".el${RESTY_IMAGE_TAG}.noarch"
elif [ "$RESTY_IMAGE_BASE" == "rhel" ]; then
  PACKAGE_TYPE="rpm"
  FPM_PARAMS="-d pcre -d perl -d perl-Time-HiRes -d openssl"
  OUTPUT_FILE_SUFFIX=".rhel${RESTY_IMAGE_TAG}.noarch"
  if [ "$RESTY_IMAGE_TAG" == "7" ]; then
    FPM_PARAMS="$FPM_PARAMS -d hostname"
  fi
fi

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
    --url 'https://getkong.org/' usr \
  && mv kong*.* /output/${KONG_PACKAGE_NAME}-${KONG_VERSION}${OUTPUT_FILE_SUFFIX}.${PACKAGE_TYPE} \
  && rm -rf /tmp/build/*
  
