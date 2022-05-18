#!/usr/bin/env bash
set -eo pipefail


CWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
BUILD_DIR="$CWD/output"

PULP_HOST=
PULP_USERNAME=
PULP_PASSWORD=

# release finals into prod, others into stage
if [[ "$KONG_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  PULP_HOST="$PULP_HOST_PROD"
  PULP_USERNAME="$PULP_PROD_USR"
  PULP_PASSWORD="$PULP_PROD_PSW"
else
  PULP_HOST="$PULP_HOST_STAGE"
  PULP_USERNAME="$PULP_STAGE_USR"
  PULP_PASSWORD="$PULP_STAGE_PSW"
fi



PULP_DOCKER_IMAGE="kong/release-script"


KONG_PACKAGE_NAME=$KONG_PACKAGE_NAME
KONG_VERSION=$KONG_VERSION


DOCKER_REPOSITORY="kong/kong"
DOCKER_REPOSITORY="${DOCKER_RELEASE_REPOSITORY:-kong/kong}"
DOCKER_TAG="latest"


case "$RESTY_IMAGE_BASE" in
  debian|ubuntu)
    OUTPUT_FILE_SUFFIX=".$RESTY_IMAGE_TAG.$ARCHITECTURE.deb"
    ;;
  centos)
    OUTPUT_FILE_SUFFIX=".el$RESTY_IMAGE_TAG.$ARCHITECTURE.rpm"
    ;;
  rhel)
    OUTPUT_FILE_SUFFIX=".rhel$RESTY_IMAGE_TAG.$ARCHITECTURE.rpm"
    ;;
  alpine)
    OUTPUT_FILE_SUFFIX=".$ARCHITECTURE.apk.tar.gz"
    ;;
  amazonlinux)
    OUTPUT_FILE_SUFFIX=".aws.$ARCHITECTURE.rpm"
    ;;
  src)
    OUTPUT_FILE_SUFFIX=".tar.gz"
    ;;
esac


DIST_FILE="$KONG_PACKAGE_NAME-$KONG_VERSION$OUTPUT_FILE_SUFFIX"


function push_docker_images() {
  docker tag \
    "localhost:5000/kong-$RESTY_IMAGE_BASE-$RESTY_IMAGE_TAG" \
    "$DOCKER_REPOSITORY:$ARCHITECTURE-$KONG_VERSION"

  echo "FROM $DOCKER_REPOSITORY:$ARCHITECTURE-$KONG_VERSION" | docker build \
    --label org.opencontainers.image.version="$KONG_VERSION" \
    --label org.opencontainers.image.created="$DOCKER_LABEL_CREATED" \
    --label org.opencontainers.image.revision="$DOCKER_LABEL_REVISION" \
    -t "$DOCKER_REPOSITORY:$ARCHITECTURE-$KONG_VERSION" -
  docker push "$DOCKER_REPOSITORY:$ARCHITECTURE-$KONG_VERSION"

  docker manifest create \
    -a "$DOCKER_REPOSITORY:$KONG_VERSION" \
       "$DOCKER_REPOSITORY:$ARCHITECTURE-$KONG_VERSION"
  docker manifest push "$DOCKER_REPOSITORY:$KONG_VERSION"

  docker tag \
    "localhost:5000/kong-$RESTY_IMAGE_BASE-$RESTY_IMAGE_TAG" \
    "$DOCKER_REPOSITORY:$ARCHITECTURE-$DOCKER_TAG"

  echo "FROM $DOCKER_REPOSITORY:$ARCHITECTURE-$DOCKER_TAG" | docker build \
    --label org.opencontainers.image.version="$KONG_VERSION" \
    --label org.opencontainers.image.created="$DOCKER_LABEL_CREATED" \
    --label org.opencontainers.image.revision="$DOCKER_LABEL_REVISION" \
    -t "$DOCKER_REPOSITORY:$ARCHITECTURE-$DOCKER_TAG" -
  docker push "$DOCKER_REPOSITORY:$ARCHITECTURE-$DOCKER_TAG"

  docker manifest create -a "$DOCKER_REPOSITORY:$DOCKER_TAG" \
    "$DOCKER_REPOSITORY:$ARCHITECTURE-$DOCKER_TAG"
  docker manifest push "$DOCKER_REPOSITORY:$DOCKER_TAG"
}


function push_package() {
  # src has no dist-version
  local dist_version="--dist-version $RESTY_IMAGE_TAG"
  if [ "$RESTY_IMAGE_BASE" == "src" ]; then
    dist_version=
    curl -L "https://github.com/Kong/kong/archive/$KONG_VERSION.tar.gz" \
      -o "output/$KONG_PACKAGE_NAME-$KONG_VERSION$OUTPUT_FILE_SUFFIX"
  fi

  if [ "$RESTY_IMAGE_BASE" == "alpine" ]; then
    dist_version=
  fi

  set -x

  local release_args="--package-type gateway"
  if [[ "$EDITION" == "enterprise" ]]; then
    release_args="$release_args --enterprise"
    # enterprise pre-releases go to `/internal/`
    if [[ "$OFFICIAL_RELEASE" == "false" ]]; then
      release_args="$release_args --internal"
    else
      release_args="$release_args --publish"
    fi
  else
    release_args="$release_args --publish"
  fi

  eval $(docker-machine env -u) # release-scripts do not need to run within the arm64 box

  docker run \
    -e PULP_HOST="$PULP_HOST" \
    -e PULP_USERNAME="$PULP_USERNAME" \
    -e PULP_PASSWORD="$PULP_PASSWORD" \
    -v "$BUILD_DIR:/files:ro" \
    -i $PULP_DOCKER_IMAGE \
          --file "/files/$DIST_FILE" \
          --dist-name "$RESTY_IMAGE_BASE" $dist_version \
          --major-version "${KONG_VERSION%%.*}.x" \
          $release_args
  set +x
}


# only push docker images for alpine builds
# this is for "release per commit" builds
if [ "$RESTY_IMAGE_BASE" == "alpine" ]; then
  push_docker_images

  if [ "$RELEASE_DOCKER_ONLY" == "true" ]; then
    exit 0
  fi
fi


push_package


echo -e "\nReleasing Kong version '$KONG_VERSION' of '$RESTY_IMAGE_BASE $RESTY_IMAGE_TAG' done"


exit 0
