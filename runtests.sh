#!/bin/bash

bin/busted --no-k -o gtest -v --exclude-tags=flaky,ipv6,cassandra,off spec/03-plugins/03-http-log/01-log_spec.lua
