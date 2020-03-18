set -e

if docker image inspect $KONG_TEST_IMAGE_NAME; then exit 0; fi

rm -rf docker-kong || true
git clone --single-branch --branch $DOCKER_KONG_VERSION https://github.com/Kong/docker-kong.git docker-kong

if [ "$RESTY_IMAGE_BASE" == "ubuntu" ] || [ "$RESTY_IMAGE_BASE" == "debian" ]; then
  cp output/*${RESTY_IMAGE_TAG}.amd64.deb docker-kong/ubuntu/kong
  BUILD_DIR="ubuntu"
elif [ "$RESTY_IMAGE_BASE" == "alpine" ]; then
  cp output/*.amd64.apk.tar.gz docker-kong/alpine/kong
  BUILD_DIR="alpine"
elif [ "$RESTY_IMAGE_BASE" == "centos" ] || [ "$RESTY_IMAGE_BASE" == "amazonlinux" ]; then
  cp output/*.amd64.rpm docker-kong/centos/kong
  BUILD_DIR="centos"
elif [ "$RESTY_IMAGE_BASE" == "rhel" ]; then
  cp output/*.rhel${RESTY_IMAGE_TAG}.amd64.rpm docker-kong/rhel/kong
  BUILD_DIR="rhel"
else
  exit 1
fi

pushd docker-kong/${BUILD_DIR}
    docker build -t $KONG_TEST_IMAGE_NAME \
    --no-cache \
    --build-arg LOCAL_KONG_PACKAGE=kong \
    --build-arg RESTY_IMAGE_BASE=$RESTY_IMAGE_BASE \
    --build-arg RESTY_IMAGE_TAG=$RESTY_IMAGE_TAG \
    --build-arg ASSET_LOCATION=local .
popd

rm -rf docker-kong || true