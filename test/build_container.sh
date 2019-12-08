if docker image inspect $KONG_TEST_CONTAINER_NAME; then exit 0; fi
RHEL=false
if [ "$RESTY_IMAGE_BASE" == "alpine" ]; then
  DOCKER_FILE="Dockerfile.alpine"
elif [ "$RESTY_IMAGE_BASE" == "ubuntu" ] || [ "$RESTY_IMAGE_BASE" == "debian" ]; then
  DOCKER_FILE="Dockerfile.deb"
elif [ "$RESTY_IMAGE_BASE" == "centos" ]; then
  DOCKER_FILE="Dockerfile.rpm"
  cp output/${KONG_PACKAGE_NAME}-${KONG_VERSION}.el${RESTY_IMAGE_TAG}.amd64.rpm output/kong.rpm
elif [ "$RESTY_IMAGE_BASE" == "amazonlinux" ]; then
  DOCKER_FILE="Dockerfile.rpm"
  cp output/${KONG_PACKAGE_NAME}-${KONG_VERSION}.aws.amd64.rpm output/kong.rpm
elif [ "$RESTY_IMAGE_BASE" == "rhel" ] && [ "$RESTY_IMAGE_TAG" == "6" ]; then
  cp output/${KONG_PACKAGE_NAME}-${KONG_VERSION}.rhel${RESTY_IMAGE_TAG}.amd64.rpm output/kong.rpm
  docker pull registry.access.redhat.com/ubi${RESTY_IMAGE_TAG}/ubi
  docker tag registry.access.redhat.com/ubi${RESTY_IMAGE_TAG}/ubi rhel:${RESTY_IMAGE_TAG}
  DOCKER_FILE="Dockerfile.rpm"
  RHEL=true
elif [ "$RESTY_IMAGE_BASE" == "rhel" ]; then
  cp output/${KONG_PACKAGE_NAME}-${KONG_VERSION}.rhel${RESTY_IMAGE_TAG}.amd64.rpm output/kong.rpm
  docker pull registry.access.redhat.com/ubi${RESTY_IMAGE_TAG}/ubi
  docker tag registry.access.redhat.com/ubi${RESTY_IMAGE_TAG}/ubi rhel:${RESTY_IMAGE_TAG}
  DOCKER_FILE="Dockerfile.rpm"
  RHEL=true
elif [ "$RESTY_IMAGE_BASE" == "src" ]; then
  exit 0
else
  echo "Unrecognized base image $RESTY_IMAGE_BASE"
  exit 1
fi

docker build \
--build-arg RESTY_IMAGE_BASE=$RESTY_IMAGE_BASE \
--build-arg RESTY_IMAGE_TAG=$RESTY_IMAGE_TAG \
--build-arg KONG_VERSION=$KONG_VERSION \
--build-arg KONG_PACKAGE_NAME=$KONG_PACKAGE_NAME \
--build-arg RHEL=$RHEL \
--build-arg REDHAT_USERNAME=$REDHAT_USERNAME \
--build-arg REDHAT_PASSWORD=$REDHAT_PASSWORD \
-f test/$DOCKER_FILE \
-t $KONG_TEST_CONTAINER_NAME .