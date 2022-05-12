set pipefail

if [[ "$EDITION" != "enterprise" ]]; then
  exit 0
fi

msg_test "Check admin API is alive"
assert_response "$KONG_ADMIN_URI" "200"

msg_test "Create a service"
assert_response "-d name=testservice -d url=http://mockbin $KONG_ADMIN_URI/services" "201"

msg_test  "List services"
assert_response "$KONG_ADMIN_URI/services" "200"

msg_test "Create a route"
assert_response "-d name=testroute -d paths=/ $KONG_ADMIN_URI/services/testservice/routes" "201"

msg_test "List services"
assert_response "$KONG_ADMIN_URI/services" "200"

msg_test "List routes"
assert_response "$KONG_ADMIN_URI/services/testservice/routes" "200"

msg_test "Proxy a request"
assert_response "$KONG_PROXY_URI/anything" "200"

it_runs_full_enterprise

msg_test "Enable Portal"
assert_response "--data config.portal=true -X PATCH $KONG_ADMIN_URI/workspaces/default" "200"

msg_test "GUI https"
assert_response "https://$TEST_HOST:8445/ --insecure" "200"

msg_test "Portal GUI"
assert_response "http://$TEST_HOST:8003" "200"

msg_test "Portal GUI https"
assert_response "https://$TEST_HOST:8446/ --insecure" "200"

msg_test "check portal"
assert_response "http://$TEST_HOST:8004/files" "200"

msg_test "Portal GUI https"
assert_response "https://$TEST_HOST:8447/files --insecure" "200"

msg_test "rbac"

stop_kong
KONG_ENFORCE_RBAC=both start_kong
wait_kong

assert_response "$KONG_ADMIN_URI/status" "401"
