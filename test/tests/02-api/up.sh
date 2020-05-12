

start_kong
wait_kong

# build API tests docker image
$CACHE_COMMAND kong/kong-build-tools:test-runner-$TEST_SHA || \
    docker build -t kong/kong-build-tools:test-runner-$TEST_SHA -f Dockerfile.test_runner .

