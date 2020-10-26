set -e

if [ "$RESTY_IMAGE_BASE" == "src" ]; then
  exit 0
fi

if docker image inspect $KONG_TEST_IMAGE_NAME; then exit 0; fi

rm -rf docker-kong || true
git clone --single-branch --branch $DOCKER_KONG_VERSION https://github.com/Kong/docker-kong.git docker-kong

if [ "$RESTY_IMAGE_BASE" == "ubuntu" ] || [ "$RESTY_IMAGE_BASE" == "debian" ]; then
  cp output/*${RESTY_IMAGE_TAG}.${ARCHITECTURE}.deb docker-kong/ubuntu/kong.deb
  BUILD_DIR="ubuntu"
elif [ "$RESTY_IMAGE_BASE" == "alpine" ]; then
  cp output/*.${ARCHITECTURE}.apk.tar.gz docker-kong/alpine/kong.tar.gz
  BUILD_DIR="alpine"
elif [ "$RESTY_IMAGE_BASE" == "centos" ] || [ "$RESTY_IMAGE_BASE" == "amazonlinux" ]; then
  cp output/*.${ARCHITECTURE}.rpm docker-kong/centos/kong.rpm
  BUILD_DIR="centos"
fi

if [ "$RESTY_IMAGE_TAG" == "stretch" ] || [ "$RESTY_IMAGE_TAG" == "jessie" ]; then
  sed -i 's/apt install --yes /gdebi -n /g' docker-kong/ubuntu/Dockerfile
  sed -i 's/unzip git/unzip git gdebi/g' docker-kong/ubuntu/Dockerfile
fi

if [ "$RESTY_IMAGE_BASE" == "rhel" ]; then
  sed -i 's/rhel7/rhel'${RESTY_IMAGE_TAG}'/' docker-kong/rhel/Dockerfile
  cp output/*.rhel${RESTY_IMAGE_TAG}.${ARCHITECTURE}.rpm docker-kong/rhel/kong.rpm
  BUILD_DIR="rhel"
else
  sed -i 's/^FROM .*/FROM '${RESTY_IMAGE_BASE}:${RESTY_IMAGE_TAG}'/' docker-kong/${BUILD_DIR}/Dockerfile
fi

pushd docker-kong/${BUILD_DIR}
    docker build -t $KONG_TEST_IMAGE_NAME \
    --no-cache \
    --build-arg ASSET=local .
    docker run -t $KONG_TEST_IMAGE_NAME kong version
popd

rm -rf docker-kong || true
