set pipefail

if [[ "$EDITION" != "enterprise" ]]; then
  exit 0
fi

msg_test "Check tracing is 'true' at status endpoint"
assert_contains "${KONG_ADMIN_URI}/status" "tracing\": true"
