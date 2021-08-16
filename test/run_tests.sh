#!/bin/bash

source test/util.sh

if $VERBOSE; then
  set -x
fi

if [[ "$RESTY_IMAGE_BASE" == "src" ]]; then
  exit 0
fi

if [[ "$KONG_DATABASE" == "postgres9" ]]; then
  KONG_DB_IMAGE="postgres:9"
  KONG_DB_PORTS="5432:5432"
elif [[ "$KONG_DATABASE" == "postgres10" ]]; then
  KONG_DB_IMAGE="postgres:10"
  KONG_DB_PORTS="5432:5432"
elif [[ "$KONG_DATABASE" == "postgres11" ]]; then
  KONG_DB_IMAGE="postgres:11"
  KONG_DB_PORTS="5432:5432"
elif [[ "$KONG_DATABASE" == "postgres12" ]]; then
  KONG_DB_IMAGE="postgres:12"
  KONG_DB_PORTS="5432:5432"
elif [[ "$KONG_DATABASE" == "postgres13" ]]; then
  KONG_DB_IMAGE="postgres:13"
  KONG_DB_PORTS="5432:5432"
elif [[ "$KONG_DATABASE" == "postgres14" ]]; then
  KONG_DB_IMAGE="postgres:14"
  KONG_DB_PORTS="5432:5432"
elif [[ "$KONG_DATABASE" == "cassandra3" ]]; then
  KONG_DB_IMAGE="cassandra:3"
  KONG_DB_PORTS="9042:9042"
fi

USE_TTY="-t"
test -t 1 && USE_TTY="-it"

for dir in test/tests/02-*; do
  msg_test "Running '$dir' tests using $KONG_DATABASE..."
  msg_test "======================================================================"

  pushd $dir
    test -f up.sh && source ./up.sh

    set -e
    test -f run.sh && source ./run.sh
    set +e

    test -f down.sh && source ./down.sh
  popd

  msg_green "=================================OK=================================="
done
