RESTY_IMAGE_BASE?=ubuntu
RESTY_IMAGE_TAG?=xenial
KONG_NETTLE_VERSION?="3.4"
KONG_GMP_VERSION?="6.1.2"
RESTY_VERSION?="1.13.6.2"
RESTY_LUAROCKS_VERSION?="2.4.3"
RESTY_OPENSSL_VERSION?="1.0.2p"
RESTY_PCRE_VERSION?="8.41"

KONG_PACKAGE_NAME?="kong-community-edition"
KONG_CONFLICTS?="kong-enterprise-edition"
KONG_LICENSE?="ASL 2.0"
KONG_SOURCE_LOCATION?="$$PWD/../kong/"
KONG_VERSION?="0.0.0"

build-kong: build-openresty-base
	docker build -f Dockerfile.kong \
	--build-arg RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	-t kong:kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) .
	docker run -t --rm -v $(KONG_SOURCE_LOCATION):/kong -v $$PWD/output/:/output \
	-e KONG_VERSION=$(KONG_VERSION) \
	-e KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	-e KONG_CONFLICTS=$(KONG_CONFLICTS) \
	-e KONG_LICENSE=$(KONG_LICENSE) \
	-e RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	-e RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	kong:kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)

build-openresty-base: build-base
	docker build -f Dockerfile.openresty \
	--build-arg KONG_NETTLE_VERSION=$(KONG_NETTLE_VERSION) \
	--build-arg KONG_GMP_VERSION=$(KONG_GMP_VERSION) \
	--build-arg RESTY_VERSION=$(RESTY_VERSION) \
	--build-arg RESTY_LUAROCKS_VERSION=$(RESTY_LUAROCKS_VERSION) \
	--build-arg RESTY_OPENSSL_VERSION=$(RESTY_OPENSSL_VERSION) \
	--build-arg RESTY_PCRE_VERSION=$(RESTY_PCRE_VERSION) \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	-t kong:openresty-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) .

build-base:
	docker build -f Dockerfile.$(RESTY_IMAGE_BASE) \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	-t kong:$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) .
