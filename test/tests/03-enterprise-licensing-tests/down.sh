
if [[ "$EDITION" != "enterprise" ]]; then
  exit 0
fi

stop_kong

