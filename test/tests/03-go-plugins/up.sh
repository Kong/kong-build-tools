
set -x

# clone plugins
git clone https://github.com/Kong/go-plugins

pushd go-plugins

  echo "Go builder image: $DOCKER_GO_BUILDER"
  rm -rf *.so

  USE_TTY="-t"
  test -t 1 && USE_TTY="-it"

  GO_PDK_VERSION=$(curl -fsL https://raw.githubusercontent.com/Kong/go-pluginserver/$KONG_GO_PLUGINSERVER_VERSION/go.mod | grep go-pdk | awk -F" " '{print $2}')
  echo "$KONG_GO_PLUGINSERVER_VERSION"
  echo "$GO_PDK_VERSION"
  docker run -d --name go-plugin --rm -v $(pwd):/plugins $DOCKER_GO_BUILDER tail -f /dev/null
  docker exec $USE_TTY go-plugin go mod edit -replace github.com/Kong/go-pdk=github.com/Kong/go-pdk@$GO_PDK_VERSION
  docker exec $USE_TTY go-plugin make
  docker stop go-plugin

popd

echo $KONG_TEST_IMAGE_NAME
docker build --build-arg KONG_TEST_IMAGE_NAME=$KONG_TEST_IMAGE_NAME \
  -f Dockerfile.custom_kong -t custom-kong-with-go-plugin .

rm -rf go-plugins

KONG_PLUGINS=go-hello KONG_GO_PLUGINS_DIR=/usr/local/kong start_kong custom-kong-with-go-plugin
wait_kong

