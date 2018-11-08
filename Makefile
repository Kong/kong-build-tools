export SHELL:=/bin/bash
export SHELLOPTS:=$(if $(SHELLOPTS),$(SHELLOPTS):)pipefail:errexit

RESTY_IMAGE_BASE?=ubuntu
RESTY_IMAGE_TAG?=xenial
PACKAGE_TYPE?=debian
KONG_NETTLE_VERSION?="3.4"
KONG_GMP_VERSION?="6.1.2"
RESTY_VERSION?="1.13.6.2"
RESTY_LUAROCKS_VERSION?="2.4.3"
RESTY_OPENSSL_VERSION?="1.1.1"
RESTY_PCRE_VERSION?="8.41"

ifeq ($(RESTY_IMAGE_BASE),alpine)
	OPENSSL_EXTRA_OPTIONS=" -no-async"
endif

KONG_PACKAGE_NAME?="kong-community-edition"
KONG_CONFLICTS?="kong-enterprise-edition"
KONG_LICENSE?="ASL 2.0"
KONG_SOURCE_LOCATION?="$$PWD/../kong/"
KONG_VERSION?="0.0.0"

release-kong:
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	KONG_VERSION=$(KONG_VERSION) \
	BINTRAY_USR=$(BINTRAY_USR) \
	BINTRAY_KEY=$(BINTRAY_KEY) \
	./release-kong.sh

clean:
	docker rmi kong:fpm
	docker rmi kong:kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)
	docker rmi kong:openresty-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)
	docker rmi kong:$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)

package-kong: build-kong
	docker build -f Dockerfile.fpm \
	-t kong:fpm .
	docker run -t --rm \
	-v $$PWD/output/build:/tmp/build \
	-v $$PWD/output:/output \
	-e KONG_VERSION=$(KONG_VERSION) \
	-e KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	-e KONG_CONFLICTS=$(KONG_CONFLICTS) \
	-e KONG_LICENSE=$(KONG_LICENSE) \
	-e RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	-e RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	kong:fpm

build-kong: build-openresty-base
	docker build -f Dockerfile.kong \
	--build-arg RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	-t kong:kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) .
	docker run -it --rm \
	-v $(KONG_SOURCE_LOCATION):/kong \
	-v $$PWD/output/build:/output/build \
	-e KONG_VERSION=$(KONG_VERSION) \
	-e KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	-e KONG_CONFLICTS=$(KONG_CONFLICTS) \
	-e KONG_LICENSE=$(KONG_LICENSE) \
	-e RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	-e RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	kong:kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)

build-openresty-base: build-base
	docker build -f Dockerfile.openresty \
	--build-arg RESTY_VERSION=$(RESTY_VERSION) \
	--build-arg RESTY_LUAROCKS_VERSION=$(RESTY_LUAROCKS_VERSION) \
	--build-arg RESTY_OPENSSL_VERSION=$(RESTY_OPENSSL_VERSION) \
	--build-arg RESTY_PCRE_VERSION=$(RESTY_PCRE_VERSION) \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	--build-arg OPENSSL_EXTRA_OPTIONS=$(OPENSSL_EXTRA_OPTIONS) \
	-t kong:openresty-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) .


build-base:
ifeq ($(RESTY_IMAGE_BASE),rhel)
	@docker build -f Dockerfile.rhel \
	--build-arg RESTY_IMAGE_BASE=registry.access.redhat.com/rhel${RESTY_IMAGE_TAG} \
	--build-arg RESTY_IMAGE_TAG=latest \
	--build-arg RHEL=true \
	--build-arg REDHAT_USERNAME=$(REDHAT_USERNAME) \
	--build-arg REDHAT_PASSWORD=$(REDHAT_PASSWORD) \
	-t kong:$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) .
else
	docker build -f Dockerfile.$(RESTY_IMAGE_BASE) \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	-t kong:$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) .
endif

test: setup_tests
	microk8s.reset
	sleep 3
	microk8s.enable storage dns registry
	sleep 3
	/snap/bin/helm init
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) KONG_VERSION=$(KONG_VERSION) test/run_tests.sh

cleanup_tests:
	microk8s.reset
	sudo snap unalias kubectl
	sudo snap remove microk8s
	sudo snap remove helm

setup_tests:
	sudo snap install microk8s --classic
	sudo snap install helm --classic
	sudo snap alias microk8s.kubectl kubectl
	#sudo iptables -P FORWARD ACCEPT
