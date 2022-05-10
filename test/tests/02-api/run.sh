set pipefail

msg_test "Check admin API is alive"
assert_response "$KONG_ADMIN_URI" "200"

msg_test "Create a service"
assert_response "-d name=testservice -d url=http://mockbin $KONG_ADMIN_URI/services" "201"

msg_test  "List services"
assert_response "$KONG_ADMIN_URI/services" "200"

msg_test "Create a route"
assert_response "-d name=testroute -d paths=/ $KONG_ADMIN_URI/services/testservice/routes" "201"

msg_test "List routes"
assert_response "$KONG_ADMIN_URI/services/testservice/routes" "200"

msg_test "List services"
assert_response "$KONG_ADMIN_URI/services" "200"

msg_test "Proxy a request"
assert_response "$KONG_PROXY_URI/anything" "200"

if [[ "$EDITION" == "enterprise" ]]; then
    it_runs_free_enterprise
fi
