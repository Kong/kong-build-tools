#!/bin/bash

cd /tmp/build

if [ "$RESTY_IMAGE_TAG" == "trusty" ]; then
  OUTPUT_FILE_SUFFIX=".trusty.all"
elif [ "$RESTY_IMAGE_TAG" == "bionic" ]; then
  OUTPUT_FILE_SUFFIX=".bionic.all"
elif [ "$RESTY_IMAGE_TAG" == "xenial" ]; then
  OUTPUT_FILE_SUFFIX=".xenial.all"
fi

FPM_PARAMS=""
if [ "$RESTY_IMAGE_BASE" == "ubuntu" ]; then
  FPM_PARAMS="-d openssl -d libpcre3 -d perl"
  PACKAGE_TYPE="deb"
elif [ "$RESTY_IMAGE_BASE" == "centos" ]; then
  PACKAGE_TYPE="rpm"
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
    --url 'https://getkong.org/' usr

mv kong*.* /output/${KONG_PACKAGE_NAME}-${KONG_VERSION}${OUTPUT_FILE_SUFFIX}.${PACKAGE_TYPE}
