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
    server {
        listen 12345;

        preread_by_lua_block {
            local http_tls = require("http.tls")
            local openssl_ctx = require("openssl.ssl.context")
            local openssl_rand = require("openssl.rand")
            local openssl_bignum = require("openssl.bignum")
            local name = require("openssl.x509.name")
            local altname = require("openssl.x509.altname")
            local pkey = require("openssl.pkey")
            local x509 = require("openssl.x509")
            local ffi = require("ffi")
            local cast = ffi.cast
            local voidpp = ffi.typeof("void**")

            -- from: https://github.com/daurnimator/lua-http/blob/master/http/server.lua
            -- Author: Daurnimator
            -- License: MIT
            local function new_ctx(host, version)
                local ctx = http_tls.new_server_context()
                if version == 2 then
                    ctx:setOptions(openssl_ctx.OP_NO_TLSv1 + openssl_ctx.OP_NO_TLSv1_1)
                end
                local crt = x509.new()
                crt:setVersion(3)
                -- serial needs to be unique or browsers will show uninformative error messages
                crt:setSerial(openssl_bignum.fromBinary(openssl_rand.bytes(16)))
                -- use the host we're listening on as canonical name
                local dn = name.new()
                dn:add("CN", host)
                crt:setSubject(dn)
                crt:setIssuer(dn) -- should match subject for a self-signed
                local alt = altname.new()
                alt:add("DNS", host)
                crt:setSubjectAlt(alt)
                -- lasts for 10 years
                crt:setLifetime(os.time(), os.time()+86400*3650)
                -- can't be used as a CA
                crt:setBasicConstraints{CA=false}
                crt:setBasicConstraintsCritical(true)
                -- generate a new private/public key pair
                local key = pkey.new({bits=2048})
                crt:setPublicKey(key)
                crt:sign(key)
                assert(ctx:setPrivateKey(key))
                assert(ctx:setCertificate(crt))
                return ctx
            end

            local server_ssl_ctx = new_ctx('example.com')

            assert(ngx.req.starttls(server_ssl_ctx))
            -- assert(ngx.req.starttls(server_ssl_ctx))
            -- ngx.thread.wait(ngx.thread.spawn(function()
            --     assert(ngx.req.starttls(server_ssl_ctx))
            -- end))
        }

        return "over TLS";
    }
--- stream_server_config
    # default: proxy_ssl_verify off;
    proxy_ssl_trusted_certificate ../../certs/trusted.crt;

    proxy_pass 127.0.0.1:12345;
    proxy_ssl on;
--- stream_response: over TLS
--- no_error_log
[warn]
[error]
[crit]
