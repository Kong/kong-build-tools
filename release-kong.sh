#!/usr/bin/env bash
set -eo pipefail

CWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

BINTRAY_ORG="kong"
BINTRAY_USR=$BINTRAY_USR
BINTRAY_KEY=$BINTRAY_KEY
BINTRAY_API="https://api.bintray.com"

KONG_PACKAGE_NAME=$KONG_PACKAGE_NAME
KONG_VERSION=$KONG_VERSION
OFFICIAL_RELEASE=$OFFICIAL_RELEASE

BUILD_DIR="output"
BINTRAY_PUT_ARGS=""
BINTRAY_DIRECTORY="${RESTY_IMAGE_BASE}/${RESTY_IMAGE_TAG}"

DOCKER_REPOSITORY="kong/kong"
DOCKER_TAG="latest"
if [ "$REPOSITORY_OS_NAME" == "next" ]; then
  DOCKER_TAG="development"
fi

if [ "$RESTY_IMAGE_BASE" == "ubuntu" ] || [ "$RESTY_IMAGE_BASE" == "debian" ]; then
  BINTRAY_DIRECTORY=""
  REPOSITORY_TYPE="${REPOSITORY_TYPE:-deb}"
  REPOSITORY_NAME="${REPOSITORY_NAME:-$KONG_PACKAGE_NAME-deb}"
  REPOSITORY_OS_NAME="${REPOSITORY_OS_NAME:-$RESTY_IMAGE_BASE}"
  OUTPUT_FILE_SUFFIX=".${RESTY_IMAGE_TAG}.${ARCHITECTURE}.deb"
  BINTRAY_PUT_ARGS=";deb_distribution=$RESTY_IMAGE_TAG;deb_component=main;deb_architecture=${ARCHITECTURE}"
elif [ "$RESTY_IMAGE_BASE" == "rhel" ]; then
  REPOSITORY_TYPE="${REPOSITORY_TYPE:-rpm}"
  REPOSITORY_NAME="${REPOSITORY_NAME:-$KONG_PACKAGE_NAME-rpm}"
  REPOSITORY_OS_NAME="${REPOSITORY_OS_NAME:-$RESTY_IMAGE_BASE}"
  OUTPUT_FILE_SUFFIX=".rhel${RESTY_IMAGE_TAG}.${ARCHITECTURE}.rpm"
elif [ "$RESTY_IMAGE_BASE" == "centos" ]; then
  REPOSITORY_TYPE="${REPOSITORY_TYPE:-rpm}"
  REPOSITORY_NAME="${REPOSITORY_NAME:-$KONG_PACKAGE_NAME-rpm}"
  REPOSITORY_OS_NAME="${REPOSITORY_OS_NAME:-$RESTY_IMAGE_BASE}"
  OUTPUT_FILE_SUFFIX=".el${RESTY_IMAGE_TAG}.${ARCHITECTURE}.rpm"
elif [ "$RESTY_IMAGE_BASE" == "alpine" ]; then
  BINTRAY_DIRECTORY=""
  REPOSITORY_TYPE="${REPOSITORY_TYPE:-generic}"
  REPOSITORY_OS_NAME="${REPOSITORY_OS_NAME:-alpine}"
  REPOSITORY_NAME="${REPOSITORY_NAME:-$KONG_PACKAGE_NAME-alpine-tar}"
  OUTPUT_FILE_SUFFIX=".${ARCHITECTURE}.apk.tar.gz"

  docker tag localhost:5000/kong-${RESTY_IMAGE_BASE}-${RESTY_IMAGE_TAG} ${DOCKER_REPOSITORY}:${ARCHITECTURE}-${KONG_VERSION}
  echo "FROM ${DOCKER_REPOSITORY}:${ARCHITECTURE}-${KONG_VERSION}" | docker build \
    --label org.opencontainers.image.version="${KONG_VERSION}" \
    --label org.opencontainers.image.created="${DOCKER_LABEL_CREATED}" \
    --label org.opencontainers.image.revision="${DOCKER_LABEL_REVISION}" \
    -t "${DOCKER_REPOSITORY}:${ARCHITECTURE}-${KONG_VERSION}" -
  docker push ${DOCKER_REPOSITORY}:${ARCHITECTURE}-${KONG_VERSION}
  
  docker manifest create -a ${DOCKER_REPOSITORY}:${KONG_VERSION} ${DOCKER_REPOSITORY}:${ARCHITECTURE}-${KONG_VERSION}
  docker manifest push ${DOCKER_REPOSITORY}:${KONG_VERSION}

  docker tag localhost:5000/kong-${RESTY_IMAGE_BASE}-${RESTY_IMAGE_TAG} ${DOCKER_REPOSITORY}:${ARCHITECTURE}-${DOCKER_TAG}
  echo "FROM ${DOCKER_REPOSITORY}:${ARCHITECTURE}-${DOCKER_TAG}" | docker build \
    --label org.opencontainers.image.version="${KONG_VERSION}" \
    --label org.opencontainers.image.created="${DOCKER_LABEL_CREATED}" \
    --label org.opencontainers.image.revision="${DOCKER_LABEL_REVISION}" \
    -t "${DOCKER_REPOSITORY}:${ARCHITECTURE}-${DOCKER_TAG}" -
  docker push ${DOCKER_REPOSITORY}:${ARCHITECTURE}-${DOCKER_TAG}
  
  docker manifest create -a ${DOCKER_REPOSITORY}:${DOCKER_TAG} ${DOCKER_REPOSITORY}:${ARCHITECTURE}-${DOCKER_TAG}
  docker manifest push ${DOCKER_REPOSITORY}:${DOCKER_TAG}
elif [ "$RESTY_IMAGE_BASE" == "amazonlinux" ]; then
  BINTRAY_DIRECTORY="amazonlinux/amazonlinux"
  REPOSITORY_TYPE="${REPOSITORY_TYPE:-rpm}"
  REPOSITORY_NAME="${REPOSITORY_NAME:-$KONG_PACKAGE_NAME-rpm}"
  REPOSITORY_OS_NAME="${REPOSITORY_OS_NAME:-aws}"
  OUTPUT_FILE_SUFFIX=".aws.${ARCHITECTURE}.rpm"
  if [ "$RESTY_IMAGE_TAG" == "2" ]; then
    BINTRAY_DIRECTORY="amazonlinux/amazonlinux2"
  fi
elif [ "$RESTY_IMAGE_BASE" == "src" ]; then
  BINTRAY_DIRECTORY=""
  REPOSITORY_TYPE="${REPOSITORY_TYPE:-generic}"
  REPOSITORY_NAME="${REPOSITORY_NAME:-$KONG_PACKAGE_NAME-src}"
  REPOSITORY_OS_NAME="${REPOSITORY_OS_NAME:-src}"
  OUTPUT_FILE_SUFFIX=".tar.gz"
  curl -L https://github.com/Kong/kong/archive/$KONG_VERSION.tar.gz -o output/$KONG_PACKAGE_NAME-$KONG_VERSION$OUTPUT_FILE_SUFFIX
fi

if [ "$RELEASE_DOCKER_ONLY" == "true" ]; then
  exit 0
fi

REPOSITORY_OS_NAME=$(sed -e 's/\//-/g' <<< $REPOSITORY_OS_NAME)
BINTRAY_PUT_ARGS="$BINTRAY_PUT_ARGS?publish=1&override=0"

DIST_FILE="$KONG_PACKAGE_NAME-$KONG_VERSION$OUTPUT_FILE_SUFFIX"
BUILD_DIR="$CWD/output/"

function print_result {
  [[ "$#" != 2 ]] && exit 1
  local status=$(echo $2 | awk -F"=" '{print $2}')
  local result=$(echo $2 | awk -F"=" '{print $1}')
  echo "$1: [status = $status] $result"
}

echo $REPOSITORY_NAME
echo $REPOSITORY_TYPE
echo $REPOSITORY_OS_NAME
echo $KONG_VERSION
echo $DIST_FILE

docker run -it \
-e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
-e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
-e AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN \
-v $PWD:/src \
--rm amazon/aws-cli s3 cp /src/output/$DIST_FILE s3://colin-release/$REPOSITORY_OS_NAME/$DIST_FILE

echo -e "\nVersion $KONG_VERSION release finished"

exit 0
