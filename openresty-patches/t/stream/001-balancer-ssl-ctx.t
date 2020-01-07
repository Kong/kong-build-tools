# vim:set ft= ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua::Stream;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 5);

#worker_connections(1024);
#no_diff();
no_long_string();

run_tests();

__DATA__

=== TEST 1: not setting SSL_CTX for upstream client connection, proxy_ssl_* are respected
--- stream_config
    upstream backend {
        server 0.0.0.1:1234;
        balancer_by_lua_block {
            local balancer = require("ngx.balancer")
            assert(balancer.set_current_peer("127.0.0.1", 12345))
        }
    }

    server {
        listen 12345 ssl;
        ssl_certificate ../../certs/test.crt;
        ssl_certificate_key ../../certs/test.key;

        return "ok";
    }
--- stream_server_config
    # default: proxy_ssl_verify off;
    proxy_ssl_trusted_certificate ../../certs/trusted.crt;

    proxy_pass backend;
    proxy_ssl on;
--- stream_response: ok
--- no_error_log
[warn]
[error]
[crit]



=== TEST 2: set SSL_CTX for upstream client connection
--- stream_config
    upstream backend {
        server 0.0.0.1:1234;
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

        return "ok";
    }
--- stream_server_config
    proxy_ssl_verify on;
    proxy_ssl_trusted_certificate ../../certs/trusted.crt;

    proxy_pass backend;
    proxy_ssl on;
--- stream_response:
--- error_log
SSL_do_handshake() failed (SSL: error:1416F086:SSL routines:tls_process_server_certificate:certificate verify failed)
--- no_error_log
[warn]
[error]



=== TEST 3: set SSL_CTX for non-https upstream
--- SKIP
--- stream_config
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
            return 200 "ok";
        }
    }
--- stream_server_config
        proxy_pass http://backend;
    }
--- stream_response: ok
--- no_error_log
[warn]
[error]
[crit]
