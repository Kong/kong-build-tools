#!/usr/bin/env bash

source $(dirname $(realpath $0))/../kong-ngx-build

set +e

g_ok=0

function t() {
    local res ok

    >&2 printf "t: $1 ? $2... "
    eval $1
    res=$?

    test $res -eq $2
    ok=$?

    if [[ ! $res -eq $2 ]]; then
        >&2 printf "\e[091merr: $res\e[0m\n"
    else
        >&2 printf "\e[092mok\n\e[0m"
    fi

    [[ $g_ok = 1 ]] || g_ok=$ok

    return $ok
}

t "version_eq 1.11.10 1.11.10" 0
t "version_eq 1.11.10 1.11" 0
t "version_eq 1.11.11.11 1.11.11.11" 0

t "version_eq 1.11.10 1.11.11" 1
t "version_eq 1.11.11.11.10.11 1.11.11.11.11.11.11" 1

t "version_eq 1.11.12a 1.11.12a" 0
t "version_eq 1.11.12a 1.11" 0

t "version_eq a.b.c a.b.c" 0
t "version_eq a.b.c.d a.b.c" 0

t "version_eq 1.2.3a.5-rc1 1.2.3a.5" 0
t "version_eq 1.2.3a.5 1.2.3a.5-rc1" 1
t "version_eq 1.2.3a.5 foobar-1.2.3a.5-rc1" 1
t "version_eq 1.2.3a.5-rc1 foobar-1.2.3a.5-rc2" 1
t "version_eq 1.2.3a.5-rc1 foobar-1.2.3a.5-rc1" 0


t "version_lt 1.11.10 1.11.11" 0
t "version_lt 1.10.11 1.11.11" 0
t "version_lt 0.11.11 1.11.11" 0
t "version_lt 1.11.10.11.11 1.11.11.11.11" 0

t "version_lt 1.11.0 1.11.0" 1
t "version_lt 1.12.0 1.11.0" 1
t "version_lt 2.12.0 1.11.0" 1

t "version_lt 1.11.10a 1.11.11b" 0
t "version_lt 1.11.10a 1.11.11bc" 0
t "version_lt 1.11.10ab 1.11.11bc" 0

t "version_lt 1.2.3a.5-rc1 foobar-1.2.3a.5-rc2" 0
t "version_lt 1.2.3a.5-rc1 foobar-1.2.3a.5-rc1" 1
t "version_lt 1.2.3a.5-rc2 foobar-1.2.3a.5-rc1" 1

# Check that it's not using direct string comparison
t "version_lt 1.11.99 1.11.100" 0
t "version_lt 1.1.99a 1.1.100a" 0


t "version_gt 1.12.0 1.11.0" 0
t "version_gt 1.12.0 1.11.0" 0
t "version_gt 2.12.0 1.11.0" 0
t "version_gt 1.11.10.11.11 1.10.11.11.11" 0

t "version_gt 1.11.10 1.11.11" 1
t "version_gt 1.10.11 1.11.11" 1
t "version_gt 0.11.11 1.11.11" 1
t "version_gt 1.11.10.11.11 1.11.11.11.11" 1

t "version_gt 1.11.0 1.11.0" 1

t "version_gt 1.11.10z 1.11.10b" 0
t "version_gt 1.11.11bc 1.11.11aa" 0
t "version_gt 1.11.10z 1.11.11b" 1

t "version_gt 1.2.3a.5-rc1 foobar-1.2.3a.5-rc2" 1
t "version_gt 1.2.3a.5-rc1 foobar-1.2.3a.5-rc1" 1
t "version_gt 1.2.3a.5-rc2 foobar-1.2.3a.5-rc1" 0


t "version_lte 1.11.10 1.11.10" 0
t "version_lte 1.11.10 1.11.11" 0
t "version_lte 1.11.12 1.11.11" 1

t "version_lte 1.2.3a.5-rc1 foobar-1.2.3a.5-rc2" 0
t "version_lte 1.2.3a.5-rc1 foobar-1.2.3a.5-rc1" 0
t "version_lte 1.2.3a.5-rc2 foobar-1.2.3a.5-rc1" 1


t "version_gte 1.11.10 1.11.10" 0
t "version_gte 1.11.12 1.11.11" 0
t "version_gte 1.11.10 1.11.11" 1

t "version_gte 1.2.3a.5-rc1 foobar-1.2.3a.5-rc2" 1
t "version_gte 1.2.3a.5-rc1 foobar-1.2.3a.5-rc1" 0
t "version_gte 1.2.3a.5-rc2 foobar-1.2.3a.5-rc1" 0

exit $g_ok
