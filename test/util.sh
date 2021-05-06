
msg_test() {
  builtin echo -en "\033[1;34m" >&1
  echo -n "===> "
  builtin echo -en "\033[1;36m" >&1
  echo -e "$@"
  builtin echo -en "\033[0m" >&1
}

msg_yellow() {
    builtin echo -en "\033[1;33m" >&1
    echo -e "$@"
    builtin echo -en "\033[0m" >&1
}

msg_green() {
  builtin echo -en "\033[1;32m" >&1
  echo -e "$@"
  builtin echo -en "\033[0m" >&1
}

msg_red() {
  builtin echo -en "\033[1;31m" >&2
  echo -e "$@"
  builtin echo -en "\033[0m" >&2
}

err_exit() {
  msg_red "$@"
  exit 1
}

wait_for() {
  local i=$1
  local char=${2:-.}
  while [ "$i" -gt 0 ]; do
    echo -n "$char"
    i=$(( i-1 ))
    sleep 1
  done
  echo
}

start_kong() {
  KONG_TEST_IMAGE_NAME=${1:-$KONG_TEST_IMAGE_NAME} docker-compose -f $TEST_COMPOSE_PATH up -d
}

stop_kong() {
  KONG_TEST_IMAGE_NAME=${1:-$KONG_TEST_IMAGE_NAME} docker-compose -f "$TEST_COMPOSE_PATH" down
}

kong_ready() {
  [ "$(docker-compose -f "$TEST_COMPOSE_PATH" ps | grep -c healthy | tr -d ' ')" == "2" ]
}

wait_kong() {
  while ! kong_ready; do
    msg_test "Waiting for Kong to be ready "
    docker-compose -f "$TEST_COMPOSE_PATH" ps
    docker-compose -f "$TEST_COMPOSE_PATH" logs kong
    wait_for 5
  done
}

assert_response() {
  RES=`curl -s -o /dev/null -w %{http_code} $1`
  [ $RES == $2 ] || err_exit "  expected $2, got $RES"
}
