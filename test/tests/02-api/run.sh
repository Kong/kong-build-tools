set pipefail

echo "Check admin API is alive"
assert_response "$KONG_ADMIN_URI" "200"

echo "Create a service"
assert_response "-d name=testservice -d url=http://httpbin.org $KONG_ADMIN_URI/services" "201"

echo  "List services"
assert_response "$KONG_ADMIN_URI/services" "200"

echo "Create a route"
assert_response "-d name=testroute -d paths=/ $KONG_ADMIN_URI/services/testservice/routes" "201"

echo  "List services"
assert_response "$KONG_ADMIN_URI/services" "200"

echo "Proxy a request"
assert_response "$KONG_PROXY_URI/anything" "200"
