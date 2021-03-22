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
* `1.15.8.3`
* `1.17.8.1`
* `1.17.8.2`
* `1.19.3.1`

Here are the instructions on how to build OpenResty with patches added to
OpenResty version `1.19.3.1`:
```bash
wget https://openresty.org/download/openresty-1.19.3.1.tar.gz
tar zxvf openresty-1.19.3.1.tar.gz
wget https://github.com/Kong/kong-build-tools/archive/master.tar.gz
tar zxvf master.tar.gz
cd openresty-1.19.3.1/bundle
for i in ../../kong-build-tools/openresty-patches-master/patches/1.19.3.1/*.patch; do patch -p1 < $i; done
```
And the output should contain:

```bash
patching file lua-resty-core-0.1.21/lib/resty/core/socket_tcp.lua
patching file lua-resty-core-0.1.21/lib/resty/core/socket_tcp.lua
patching file lua-resty-core-0.1.21/lib/resty/core/socket_tcp.lua
patching file lua-resty-core-0.1.21/lib/resty/core/socket_tcp.lua
patching file lua-resty-core-0.1.21/lib/resty/core/socket_tcp.lua
patching file lua-resty-core-0.1.21/lib/resty/core/socket_tcp.lua
patching file lua-resty-core-0.1.21/lib/ngx/balancer.lua
patching file lua-resty-websocket-0.08/lib/resty/websocket/client.lua
patching file nginx-1.19.3/src/http/ngx_http_upstream.c
patching file nginx-1.19.3/src/http/ngx_http_special_response.c
patching file nginx-1.19.3/src/stream/ngx_stream_proxy_module.c
patching file nginx-1.19.3/src/http/modules/ngx_http_grpc_module.c
patching file ngx_lua-0.10.19/src/ngx_http_lua_socket_tcp.c
patching file ngx_lua-0.10.19/src/ngx_http_lua_socket_tcp.h
patching file ngx_lua-0.10.19/src/ngx_http_lua_socket_tcp.c
patching file ngx_lua-0.10.19/src/ngx_http_lua_socket_tcp.c
patching file ngx_lua-0.10.19/src/ngx_http_lua_socket_tcp.c
patching file ngx_lua-0.10.19/src/ngx_http_lua_socket_tcp.c
patching file ngx_lua-0.10.19/src/ngx_http_lua_balancer.c
patching file ngx_lua-0.10.19/src/ngx_http_lua_common.h
patching file ngx_lua-0.10.19/src/ngx_http_lua_module.c
patching file ngx_lua-0.10.19/src/ngx_http_lua_balancer.c
patching file ngx_lua-0.10.19/src/ngx_http_lua_balancer.c
patching file ngx_lua-0.10.19/src/ngx_http_lua_common.h
patching file ngx_stream_lua-0.0.9/src/api/ngx_stream_lua_api.h
```

After applying patches you can continue following [build Kong from sources documentation](https://getkong.org/install/source/):


## License

```
Copyright 2018-2020 Kong Inc.

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
