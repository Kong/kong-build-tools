docker run \
  --rm \
  -t --network host \
  -e RESTY_VERSION=$RESTY_VERSION \
  -e KONG_VERSION=$KONG_VERSION \
  -e ADMIN_URI=$KONG_ADMIN_URI \
  -e PROXY_URI=$KONG_PROXY_URI \
  -v $PWD:/app \
  kong/kong-build-tools:test-runner-$TEST_SHA \
    /bin/bash -c "py.test -p no:logging -p no:warnings test_*.tavern.yaml"
