#!/usr/bin/env bash

source $(dirname $(realpath $0))/../kong-ngx-build

set +e

g_ok=0

function t() {
    local res

    >&2 printf "t: $1 is core $2 ? ... "
    res=$($1)

    if [ $res != $2 ]; then
        >&2 printf "\e[091merr: $res\e[0m\n"
        g_ok=1
    else
        >&2 printf "\e[092mok\n\e[0m"
    fi
}

t "parse_nginx_core_version 1.11.2.1" "1.11.2"

t "parse_nginx_core_version 1.13.6.1" "1.13.6"
t "parse_nginx_core_version 1.13.6.2" "1.13.6"

t "parse_nginx_core_version 1.15.8.1rc1" "1.15.8"
t "parse_nginx_core_version 1.15.8.1" "1.15.8"

exit $g_ok
