# vim:set ft= ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 6 + 2);

#worker_connections(1024);
#no_diff();
no_long_string();

run_tests();

__DATA__

=== TEST 1: not setting SSL_CTX for upstream client connection, proxy_ssl_* are respected
--- http_config
    upstream backend {
        server 0.0.0.1;
        balancer_by_lua_block {
            local balancer = require("ngx.balancer")
            assert(balancer.set_current_peer("127.0.0.1", 12345))
        }
    }

    server {
        listen 12345 ssl;
        ssl_certificate ../../certs/test.crt;
        ssl_certificate_key ../../certs/test.key;

        server_tokens off;
        location / {
            return 200 "ok";
        }
    }
--- config
    # default: proxy_ssl_verify off;
    proxy_ssl_trusted_certificate ../../certs/trusted.crt;

    location = /t {
        proxy_pass https://backend;
    }
--- request
GET /t
--- response_body: ok
--- error_code: 200
--- no_error_log
[warn]
[error]
[crit]



=== TEST 2: set SSL_CTX for upstream client connection
--- http_config
    upstream backend {
        server 0.0.0.1;
        balancer_by_lua_block {
            local http_tls = require("http.tls")
            local openssl_ctx = require("openssl.ssl.context")
            local balancer = require("ngx.balancer")
            local ffi = require("ffi")
            local cast = ffi.cast
            local voidpp = ffi.typeof("void**")

            local client_ssl_ctx = http_tls.new_client_context()
            -- this overrides any proxy_ssl_* configs
            client_ssl_ctx:setVerify(openssl_ctx.VERIFY_PEER)

            assert(balancer.set_ssl_ctx(cast(voidpp, client_ssl_ctx)[0]))
            assert(balancer.set_current_peer("127.0.0.1", 12345))
        }
    }

    server {
        listen 12345 ssl;
        ssl_certificate ../../certs/test.crt;
        ssl_certificate_key ../../certs/test.key;

        server_tokens off;
        location = / {
            return 200 "ok";
        }
    }
--- config
    proxy_ssl_verify on;
    proxy_ssl_trusted_certificate ../../certs/trusted.crt;

    location = /t {
        proxy_pass https://backend;
    }
--- request
GET /t
--- response_body_like: 502 Bad Gateway
--- error_code: 502
--- error_log
SSL_do_handshake() failed (SSL: error:1416F086:SSL routines:tls_process_server_certificate:certificate verify failed)
--- no_error_log
[warn]
[error]



=== TEST 3: set SSL_CTX for non-https upstream (skipping because set_ssl_ctx enables TLS unconditionally right now regardless of what was passed to proxy_pass)
--- SKIP
--- http_config
    upstream backend {
        server 0.0.0.1;
        balancer_by_lua_block {
            local http_tls = require("http.tls")
            local openssl_ctx = require("openssl.ssl.context")
            local balancer = require("ngx.balancer")
            local ffi = require("ffi")
            local cast = ffi.cast
            local voidpp = ffi.typeof("void**")

            local client_ssl_ctx = http_tls.new_client_context()
            -- this overrides any proxy_ssl_* configs
            client_ssl_ctx:setVerify(openssl_ctx.VERIFY_PEER)

            assert(balancer.set_ssl_ctx(cast(voidpp, client_ssl_ctx)[0]))
            assert(balancer.set_current_peer("127.0.0.1", 12345))
        }
    }

    server {
        listen 12345;

        server_tokens off;
        location / {
            return 200 "ok";
        }
    }
--- config
    location = /t {
        proxy_pass http://backend;
    }
--- request
GET /t
--- response_body: ok
--- error_code: 200
--- no_error_log
[warn]
[error]
[crit]



=== TEST 4: set SSL_CTX should not affect unrelated requests
--- http_config
    lua_shared_dict flag 16k;

    upstream backend {
        server 0.0.0.1;
        balancer_by_lua_block {
            local balancer = require("ngx.balancer")

            if ngx.shared.flag:incr("executed", 1, 0) % 2 == 0 then
                assert(balancer.set_current_peer("127.0.0.1", 12346))
                return
            end

            local http_tls = require("http.tls")
            local openssl_ctx = require("openssl.ssl.context")
            local ffi = require("ffi")
            local cast = ffi.cast
            local voidpp = ffi.typeof("void**")

            local client_ssl_ctx = http_tls.new_client_context()
            -- this overrides any proxy_ssl_* configs
            client_ssl_ctx:setVerify(openssl_ctx.VERIFY_NONE)

            assert(balancer.set_ssl_ctx(cast(voidpp, client_ssl_ctx)[0]))
            assert(balancer.set_current_peer("127.0.0.1", 12345))
        }
    }

    server {
        listen 12345 ssl;
        ssl_certificate ../../certs/test.crt;
        ssl_certificate_key ../../certs/test.key;

        server_tokens off;
        location / {
            return 200 "ok";
        }
    }

    server {
        listen 12346;

        server_tokens off;
        location / {
            return 200 "ok1";
        }
    }
--- config
    location = /t {
        proxy_pass https://backend;
    }

    location = /u {
        proxy_pass http://backend;
    }
--- request eval
["GET /t", "GET /u"]
--- response_body eval
["ok", "ok1"]
--- error_code eval
[200, 200]
--- no_error_log
[warn]
[error]
[crit]
