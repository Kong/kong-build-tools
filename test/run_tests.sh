#!/bin/bash

source test/util.sh

if $VERBOSE; then
  set -x
fi

if [[ "$RESTY_IMAGE_BASE" == "src" ]]; then
  exit 0
fi

USE_TTY="-t"
test -t 1 && USE_TTY="-it"

for dir in test/tests/*; do
  msg_test "Running '$dir' tests..."
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

