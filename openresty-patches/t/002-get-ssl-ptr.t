# vim:set ft= ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4 + 2);

#worker_connections(1024);
#no_diff();
no_long_string();

run_tests();

__DATA__

=== TEST 1: get SSL*
--- http_config
    server {
        listen 12345 ssl;
        ssl_certificate ../../certs/test.crt;
        ssl_certificate_key ../../certs/test.key;

        server_tokens off;
        location / {
            rewrite_by_lua_block {
                local ffi = require("ffi")
                local pushssl = require("openssl.ssl").pushffi -- will define SSL* in ffi
                local get_ssl_pointer = require("ngx.ssl").get_ssl_pointer
                local SSLp = ffi.typeof("SSL*")

                local ptr, err = get_ssl_pointer()
                if not ptr then
                    return nil, err
                end
                ptr = ffi.cast(SSLp, ptr)
                local ssl = pushssl(ptr)

                ngx.say("SNI is: ", ssl:getHostName())
                return ngx.exit(200)
            }
        }
    }
--- config
    proxy_ssl_trusted_certificate ../../certs/trusted.crt;

    location = /t {
        proxy_ssl_name "test_sni";
        proxy_ssl_server_name on;
        proxy_pass https://127.0.0.1:12345;
    }
--- request
GET /t
--- response_body
SNI is: test_sni
--- error_code: 200
--- no_error_log
[warn]
[error]
[crit]
