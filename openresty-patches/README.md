# OpenResty Patches for Kong

This repository contains patches for OpenResty to be included in Kong
distributions. Kong users building the OpenResty from sources may also
apply these patches to their OpenResty bundle.

## How to Apply Patches Manually?

While Kong Inc. takes care of pushing these patches to all the Kong
Community Edition (CE) and Kong Enterprise Edition releases (in
different flavors of distribution packages), you might want to [build
Kong from the sources](https://getkong.org/install/source/), that currently
also means to build OpenResty from sources. Before building OpenResty,
you need to apply these patches.

Currently we have patches for following OpenResty releases, though you might
get them applied to other versions:

* `1.13.6.1`
* `1.13.6.2`
* `1.15.8.1`
* `1.15.8.2`

Here are the instructions on how to build OpenResty with patches added to
OpenResty version `1.15.8.2`:
```bash
wget https://openresty.org/download/openresty-1.15.8.2.tar.gz
tar zxvf openresty-1.15.8.2.tar.gz
wget https://github.com/Kong/openresty-patches/archive/master.tar.gz
tar zxvf master.tar.gz
cd openresty-1.15.8.2/bundle
for i in ../../openresty-patches-master/patches/1.15.8.2/*.patch; do patch -p1 < $i; done
```
And the output should contain:

```bash
patching file LuaJIT-2.1-20190507/src/lj_tab.c
patching file LuaJIT-2.1-20190507/src/lj_asm_arm.h
patching file lua-resty-core-0.1.17/lib/ngx/balancer.lua
patching file lua-resty-core-0.1.17/lib/ngx/ssl.lua
patching file nginx-1.15.8/src/stream/ngx_stream.h
patching file nginx-1.15.8/src/stream/ngx_stream_proxy_module.c
patching file nginx-1.15.8/src/core/ngx_connection.c
patching file nginx-1.15.8/src/core/ngx_connection.h
patching file nginx-1.15.8/src/event/ngx_event_accept.c
patching file nginx-1.15.8/src/http/ngx_http.c
patching file nginx-1.15.8/src/http/ngx_http_core_module.c
patching file nginx-1.15.8/src/http/ngx_http_core_module.h
patching file nginx-1.15.8/src/http/ngx_http_request.c
patching file nginx-1.15.8/src/stream/ngx_stream.c
patching file nginx-1.15.8/src/stream/ngx_stream_core_module.c
patching file nginx-1.15.8/src/stream/ngx_stream.h
patching file nginx-1.15.8/src/stream/ngx_stream_handler.c
patching file nginx-1.15.8/auto/os/linux
patching file nginx-1.15.8/src/os/unix/ngx_linux_config.h
patching file nginx-1.15.8/src/event/ngx_event_openssl.c
patching file nginx-1.15.8/src/event/ngx_event_openssl.c
patching file nginx-1.15.8/src/event/ngx_event_openssl.h
patching file ngx_lua-0.10.15/src/ngx_http_lua_balancer.c
patching file ngx_lua-0.10.15/src/ngx_http_lua_balancer.c
patching file ngx_lua-0.10.15/src/ngx_http_lua_ssl_certby.c
patching file ngx_lua-0.10.15/t/140-ssl-c-api.t
patching file ngx_lua-0.10.15/src/ngx_http_lua_util.c
patching file ngx_stream_lua-0.0.7/src/ngx_stream_lua_balancer.c
patching file ngx_stream_lua-0.0.7/src/ngx_stream_lua_util.h
patching file ngx_stream_lua-0.0.7/src/ngx_stream_lua_control.c
patching file ngx_stream_lua-0.0.7/src/ngx_stream_lua_variable.c
patching file ngx_stream_lua-0.0.7/src/ngx_stream_lua_common.h
patching file ngx_stream_lua-0.0.7/src/ngx_stream_lua_util.c
patching file ngx_stream_lua-0.0.7/src/ngx_stream_lua_ssl.c
patching file ngx_stream_lua-0.0.7/src/ngx_stream_lua_ssl.h
patching file ngx_stream_lua-0.0.7/src/ngx_stream_lua_util.c
```

Here are the instructions on how to build OpenResty with patches added to
OpenResty version `1.13.6.2`:

```bash
wget https://openresty.org/download/openresty-1.13.6.2.tar.gz
tar zxvf openresty-1.13.6.2.tar.gz
wget https://github.com/Kong/openresty-patches/archive/master.tar.gz
tar zxvf master.tar.gz
cd openresty-1.13.6.2/bundle/
for i in ../../openresty-patches-master/patches/1.13.6.2/*.patch; do patch -p1 < $i; done
```
And the output should contain:

```bash
patching file lua-resty-core-0.1.15/lib/ngx/semaphore.lua
patching file lua-resty-core-0.1.15/t/stream/semaphore.t
patching file lua-resty-core-0.1.15/lib/ngx/balancer.lua
patching file lua-resty-core-0.1.15/lib/ngx/ssl.lua
patching file lua-resty-core-0.1.15/t/stream/ssl.t
patching file lua-resty-core-0.1.15/lib/ngx/ssl.lua
patching file lua-resty-core-0.1.15/lib/ngx/errlog.lua
patching file lua-resty-core-0.1.15/lib/resty/core/base.lua
patching file lua-resty-core-0.1.15/lib/resty/core/phase.lua
patching file lua-resty-core-0.1.15/.travis.yml
patching file lua-resty-core-0.1.15/lib/ngx/errlog.lua
patching file lua-resty-core-0.1.15/t/errlog.t
patching file lua-resty-core-0.1.15/t/stream/errlog-raw-log.t
patching file lua-resty-core-0.1.15/t/stream/errlog.t
patching file lua-resty-core-0.1.15/lib/ngx/re.lua
patching file nginx-1.13.6/src/stream/ngx_stream.h
patching file nginx-1.13.6/src/stream/ngx_stream_proxy_module.c
patching file nginx-1.13.6/src/core/ngx_connection.c
patching file nginx-1.13.6/src/core/ngx_connection.h
patching file nginx-1.13.6/src/event/ngx_event_accept.c
patching file nginx-1.13.6/src/http/ngx_http.c
patching file nginx-1.13.6/src/http/ngx_http_core_module.c
patching file nginx-1.13.6/src/http/ngx_http_core_module.h
patching file nginx-1.13.6/src/http/ngx_http_request.c
patching file nginx-1.13.6/src/stream/ngx_stream.c
patching file nginx-1.13.6/src/stream/ngx_stream_core_module.c
patching file nginx-1.13.6/src/stream/ngx_stream.h
patching file nginx-1.13.6/src/stream/ngx_stream_handler.c
patching file nginx-1.13.6/auto/os/linux
patching file nginx-1.13.6/src/os/unix/ngx_linux_config.h
patching file nginx-1.13.6/src/event/ngx_event_openssl.c
patching file nginx-1.13.6/src/event/ngx_event_openssl.c
patching file nginx-1.13.6/src/event/ngx_event_openssl.h
patching file nginx-1.13.6/src/stream/ngx_stream_ssl_preread_module.c
patching file nginx-1.13.6/src/stream/ngx_stream_ssl_preread_module.c
patching file ngx_lua-0.10.13/src/ngx_http_lua_balancer.c
patching file ngx_lua-0.10.13/src/ngx_http_lua_balancer.c
patching file ngx_lua-0.10.13/src/ngx_http_lua_ssl_certby.c
patching file ngx_lua-0.10.13/t/140-ssl-c-api.t
patching file ngx_lua-0.10.13/src/ngx_http_lua_util.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_balancer.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_util.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_control.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_variable.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_common.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_util.c
patching file ngx_stream_lua-0.0.5/config
patching file ngx_stream_lua-0.0.5/src/ddebug.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_initworkerby.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_module.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_probe.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_regex.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_semaphore.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_semaphore.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_util.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_shdict.c
patching file ngx_stream_lua-0.0.5/config
patching file ngx_stream_lua-0.0.5/src/api/ngx_stream_lua_api.h
patching file ngx_stream_lua-0.0.5/src/ddebug.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_api.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_args.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_args.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_balancer.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_balancer.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_cache.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_cache.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_clfactory.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_clfactory.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_common.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_config.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_config.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_consts.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_consts.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_contentby.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_contentby.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_control.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_control.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_coroutine.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_coroutine.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_ctx.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_ctx.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_directive.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_directive.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_exception.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_exception.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_initby.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_initby.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_initworkerby.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_initworkerby.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_lex.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_lex.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_log.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_log.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_logby.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_logby.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_misc.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_misc.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_module.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_output.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_output.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_pcrefix.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_pcrefix.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_phase.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_phase.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_probe.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_regex.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_regex.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_script.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_script.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_semaphore.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_semaphore.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_shdict.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_sleep.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_sleep.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_socket_tcp.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_socket_tcp.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_socket_udp.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_socket_udp.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_ssl.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_ssl.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_ssl_certby.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_ssl_certby.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_string.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_string.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_time.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_time.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_timer.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_timer.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_uthread.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_uthread.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_util.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_util.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_variable.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_variable.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_worker.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_worker.h
patching file ngx_stream_lua-0.0.5/t/139-ssl-cert-by.t
patching file ngx_stream_lua-0.0.5/t/140-ssl-c-api.t
patching file ngx_stream_lua-0.0.5/t/cert/test2.crt
patching file ngx_stream_lua-0.0.5/t/cert/test2.key
patching file ngx_stream_lua-0.0.5/t/cert/test_ecdsa.crt
patching file ngx_stream_lua-0.0.5/t/cert/test_ecdsa.key
patching file ngx_stream_lua-0.0.5/config
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_common.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_directive.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_directive.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_log.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_log.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_log_ringbuf.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_log_ringbuf.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_module.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_ssl.c
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_ssl.h
patching file ngx_stream_lua-0.0.5/src/ngx_stream_lua_util.c
```

Here are the instructions on how to build OpenResty with patches added to
OpenResty version `1.13.6.1`:

```bash
wget https://openresty.org/download/openresty-1.13.6.1.tar.gz
tar zxvf openresty-1.13.6.1.tar.gz
wget https://github.com/Kong/openresty-patches/archive/master.tar.gz
tar zxvf master.tar.gz
cd openresty-1.13.6.1/bundle/
for i in ../../openresty-patches-master/patches/1.13.6.1/*.patch; do patch -p1 < $i; done
```

And the output should contain:

```bash
patching file lua-resty-core-0.1.13/lib/ngx/balancer.lua
patching file lua-resty-core-0.1.13/lib/ngx/balancer.lua
patching file ngx_lua-0.10.11/src/ngx_http_lua_balancer.c
patching file ngx_lua-0.10.11/src/ngx_http_lua_balancer.c
patching file ngx_lua-0.10.11/src/ngx_http_lua_ssl_certby.c
patching file ngx_lua-0.10.11/t/140-ssl-c-api.t
```

After applying patches you can continue following [build Kong from sources documentation](https://getkong.org/install/source/):

**NOTE!** `1.13.6.1` will only build with `OpenSSL` `1.0.x`, while `1.13.6.2`
and `1.15.8.1` require `OpenSSL` `1.1.x` when these patches are applied. Please
adjust the following to point to correct `OpenSSL` as needed, e.g.:


**1.13.6.2 or 1.15.8.1:**
```
--with-cc-opt="-I/usr/local/share/openssl@1.1/include"
--with-ld-opt="-L/usr/local/share/openssl@1.1/lib"
```

**1.13.6.1:**
```
--with-cc-opt="-I/usr/local/share/openssl/include"
--with-ld-opt="-L/usr/local/share/openssl/lib"
```

You may need to adjust the paths to match to your system.


```bash
$ ./configure \
    --with-pcre-jit \
    --with-ipv6 \
    --with-http_realip_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_v2_module \
    --with-stream_ssl_preread_module \
    --with-stream_realip_module \
    --with-luajit-xcflags="-DLUAJIT_NUMMODE=2" \
    -j8 \
    … 
```

## License

```
Copyright 2018-2019 Kong Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
