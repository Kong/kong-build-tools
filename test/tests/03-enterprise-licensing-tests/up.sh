
if [[ "$EDITION" != "enterprise" ]]; then
  exit 0
fi

KONG_LICENSE_URL="https://download.konghq.com/internal/kong-gateway/license.json"

if [[ "$PULP_USERNAME" == "" ]]; then
  msg_yellow "PULP_USERNAME is not set, might not be able to download the license!"
fi

if [[ "$PULP_PASSWORD" == "" ]]; then
  msg_yellow "PULP_PASSWORD is not set, might not be able to download the license!"
fi

KONG_LICENSE_DATA=$(curl -s -L -u"$PULP_USERNAME:$PULP_PASSWORD" $KONG_LICENSE_URL)
if [[ ! $KONG_LICENSE_DATA == *"signature"* || ! $KONG_LICENSE_DATA == *"payload"* ]]; then
  # the check above is a bit lame, but the best we can do without requiring
  # yet more additional dependenies like jq or similar.
  err_exit "failed to download the Kong Enterprise license file!
  $KONG_LICENSE_DATA"
fi

export KONG_LICENSE_DATA
export KONG_PORTAL
export KONG_ENFORCE_RBAC

start_kong
wait_kong
