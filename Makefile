.PHONY: test build-kong

export SHELL:=/bin/bash

RESTY_IMAGE_BASE?=ubuntu
RESTY_IMAGE_TAG?=bionic
PACKAGE_TYPE?=deb
PACKAGE_TYPE?=debian

TEST_ADMIN_PROTOCOL?=http://
TEST_ADMIN_PORT?=8001
TEST_HOST?=localhost
TEST_ADMIN_URI?=$(TEST_ADMIN_PROTOCOL)$(TEST_HOST):$(TEST_ADMIN_PORT)
TEST_PROXY_PROTOCOL?=http://
TEST_PROXY_PORT?=8000
TEST_PROXY_URI?=$(TEST_PROXY_PROTOCOL)$(TEST_HOST):$(TEST_PROXY_PORT)

KONG_SOURCE_LOCATION?="$$PWD/../kong/"
EDITION?=`grep EDITION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
KONG_PACKAGE_NAME?="kong"
KONG_CONFLICTS?="kong-enterprise-edition"
KONG_LICENSE?="ASL 2.0"

PRIVATE_REPOSITORY?=true
KONG_TEST_CONTAINER_TAG?=5000/kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)
KONG_TEST_CONTAINER_NAME?=localhost:$(KONG_TEST_CONTAINER_TAG)
KONG_VERSION?=`echo $(KONG_SOURCE_LOCATION)/kong-*.rockspec | sed 's,.*/,,' | cut -d- -f2`
RESTY_VERSION ?= `grep RESTY_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
RESTY_LUAROCKS_VERSION ?= `grep RESTY_LUAROCKS_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
RESTY_OPENSSL_VERSION ?= `grep RESTY_OPENSSL_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
RESTY_PCRE_VERSION ?= `grep RESTY_PCRE_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
KONG_GMP_VERSION ?= `grep KONG_GMP_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
KONG_NETTLE_VERSION ?= `grep KONG_NETTLE_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
OPENRESTY_PATCHES ?= 1
RESTY_CONFIG_OPTIONS ?= "--with-cc-opt='-I/tmp/openssl/include' \
  --with-ld-opt='-L/tmp/openssl -Wl,-rpath,/usr/local/kong/lib' \
  --with-pcre=/tmp/pcre-${RESTY_PCRE_VERSION} \
  --with-pcre-jit \
  --with-http_realip_module \
  --with-http_ssl_module \
  --with-http_stub_status_module \
  --with-http_v2_module \
  --with-stream_ssl_preread_module \
  --with-stream_realip_module \
  "
LIBYAML_VERSION ?= 0.2.1

DOCKER_MACHINE_ARM64_NAME?=docker-machine-arm64-${USER}

ifeq ($(RESTY_IMAGE_BASE),alpine)
	OPENSSL_EXTRA_OPTIONSs=" -no-async"
endif

BUILDX?=false
ifndef AWS_ACCESS_KEY
	BUILDX=false
else ifeq ($(RESTY_IMAGE_TAG),xenial)
	BUILDX=true
endif

BUILDX_INFO ?= $(shell docker buildx 2>&1 >/dev/null; echo $?)
ifneq ($(BUILDX_INFO),)
	BUILDX=false
endif


ifeq ($(BUILDX),false)
	DOCKER_COMMAND?=docker build --build-arg BUILDPLATFORM=x/amd64
else
	DOCKER_COMMAND?=docker buildx build --push --platform="linux/amd64,linux/arm64"
endif

# Cache gets automatically busted every week. Set this to unique value to skip the cache
CACHE_BUSTER?=`date +%V`
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
TEST_SHA=$$(git log -1 --pretty=format:"%h" -- ${ROOT_DIR}/test/)${CACHE_BUSTER}

REQUIREMENTS_SHA=$$(md5sum $(KONG_SOURCE_LOCATION)/.requirements | cut -d' ' -f 1)
BUILD_TOOLS_SHA=$$(git rev-parse --short HEAD)
KONG_SHA=$$(git --git-dir=$(KONG_SOURCE_LOCATION)/.git rev-parse --short HEAD)

DOCKER_BASE_SUFFIX=${BUILD_TOOLS_SHA}${CACHE_BUSTER}
DOCKER_OPENRESTY_SUFFIX=${BUILD_TOOLS_SHA}-${REQUIREMENTS_SHA}${OPENRESTY_PATCHES}-${CACHE_BUSTER}
DOCKER_KONG_SUFFIX=${BUILD_TOOLS_SHA}${OPENRESTY_PATCHES}-${KONG_VERSION}-${KONG_SHA}-${CACHE_BUSTER}
DOCKER_TEST_SUFFIX=${BUILD_TOOLS_SHA}-${KONG_SHA}-${CACHE_BUSTER}

CACHE?=true

ifeq ($(CACHE),true)
	CACHE_COMMAND?=docker pull
else
    CACHE_COMMAND?=false
endif

UPDATE_CACHE?=$(CACHE)
ifeq ($(UPDATE_CACHE),true)
	UPDATE_CACHE_COMMAND?=docker push
else
	UPDATE_CACHE_COMMAND?=false
endif

debug:
	@echo ${CACHE}
	@echo ${BUILDX}
	@echo ${UPDATE_CACHE}
	@echo ${CACHE_COMMAND}
	@echo ${UPDATE_CACHE_COMMAND}
	@echo ${DOCKER_COMMAND}
	@echo ${BUILDX_INFO}

setup-ci:
ifneq ($(RESTY_IMAGE_BASE),src)
	.ci/setup_ci.sh
	$(MAKE) setup-build
endif

setup-build: cleanup-build
ifeq ($(RESTY_IMAGE_BASE),src)
	@echo "nothing to be done"
else ifeq ($(BUILDX),true)
	docker buildx create --name multibuilder
	docker-machine create --driver amazonec2 \
	--amazonec2-instance-type a1.medium \
	--amazonec2-region us-east-1 \
	--amazonec2-ami ami-0c46f9f09e3a8c2b5 \
	--amazonec2-vpc-id vpc-74f9ac0c \
	--amazonec2-monitoring \
	--amazonec2-tags created-by,${USER} ${DOCKER_MACHINE_ARM64_NAME}
	docker context create ${DOCKER_MACHINE_ARM64_NAME} --docker \
	host=tcp://`docker-machine config ${DOCKER_MACHINE_ARM64_NAME} | grep tcp | awk -F "//" '{print $$2}'`,\
	ca=`docker-machine config ${DOCKER_MACHINE_ARM64_NAME} | grep tlscacert | awk -F "=" '{print $$2}' | tr -d "\""`,\
	cert=`docker-machine config ${DOCKER_MACHINE_ARM64_NAME} | grep tlscert | awk -F "=" '{print $$2}' | tr -d "\""`,\
	key=`docker-machine config ${DOCKER_MACHINE_ARM64_NAME} | grep tlskey | awk -F "=" '{print $$2}' | tr -d "\""`
	docker buildx create --name multibuilder --append ${DOCKER_MACHINE_ARM64_NAME}
	docker buildx inspect multibuilder --bootstrap
	docker buildx use multibuilder
endif

cleanup-build:
ifeq ($(RESTY_IMAGE_BASE),src)
	@echo "nothing to be done"
else ifeq ($(BUILDX),true)
	-docker buildx use default
	-docker buildx rm multibuilder
	-docker context rm ${DOCKER_MACHINE_ARM64_NAME}
	-docker-machine rm --force ${DOCKER_MACHINE_ARM64_NAME}
endif

build-base:
ifeq ($(RESTY_IMAGE_BASE),src)
	@echo "nothing to be done"
else ifeq ($(RESTY_IMAGE_BASE),rhel)
	docker pull centos:${RESTY_IMAGE_TAG}
	docker tag centos:${RESTY_IMAGE_TAG} rhel:${RESTY_IMAGE_TAG}
	PACKAGE_TYPE=rpm
endif
	$(CACHE_COMMAND) kong/kong-build-tools:$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_BASE_SUFFIX) || \
	( $(DOCKER_COMMAND) -f Dockerfile.$(PACKAGE_TYPE) \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	-t kong/kong-build-tools:$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_BASE_SUFFIX) . )
	-$(UPDATE_CACHE_COMMAND) kong/kong-build-tools:$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_BASE_SUFFIX)

build-openresty:
ifeq ($(RESTY_IMAGE_BASE),src)
	@echo "nothing to be done"
else
	$(CACHE_COMMAND) kong/kong-build-tools:openresty-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_OPENRESTY_SUFFIX) || \
	( $(MAKE) build-base ; \
	$(DOCKER_COMMAND) -f Dockerfile.openresty \
	--build-arg RESTY_VERSION=$(RESTY_VERSION) \
	--build-arg RESTY_LUAROCKS_VERSION=$(RESTY_LUAROCKS_VERSION) \
	--build-arg RESTY_OPENSSL_VERSION=$(RESTY_OPENSSL_VERSION) \
	--build-arg RESTY_PCRE_VERSION=$(RESTY_PCRE_VERSION) \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	--build-arg DOCKER_BASE_SUFFIX=$(DOCKER_BASE_SUFFIX) \
	--build-arg OPENSSL_EXTRA_OPTIONS=$(OPENSSL_EXTRA_OPTIONS) \
	--build-arg LIBYAML_VERSION=$(LIBYAML_VERSION) \
	--build-arg RESTY_CONFIG_OPTIONS=$(RESTY_CONFIG_OPTIONS) \
	--build-arg EDITION=$(EDITION) \
	--build-arg KONG_GMP_VERSION=$(KONG_GMP_VERSION) \
	--build-arg KONG_NETTLE_VERSION=$(KONG_NETTLE_VERSION) \
	--build-arg OPENRESTY_PATCHES=$(OPENRESTY_PATCHES) \
	-t kong/kong-build-tools:openresty-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_OPENRESTY_SUFFIX) . )
	-$(UPDATE_CACHE_COMMAND) kong/kong-build-tools:openresty-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_OPENRESTY_SUFFIX)
endif
ifeq ($(RESTY_IMAGE_TAG),'xenial')
	exit 0
endif
ifeq ($(OPENRESTY_PATCHES),1)
	docker run -t --rm kong/kong-build-tools:openresty-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_OPENRESTY_SUFFIX) \
	/bin/sh -c "test -f /work/openresty-$(RESTY_VERSION)/bundle/.patch_applied"
else
	docker run -t --rm kong/kong-build-tools:openresty-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_OPENRESTY_SUFFIX) \
	/bin/sh -c "test -f /work/openresty-$(RESTY_VERSION)/bundle/.patch_applied || exit 0"
endif

ifeq ($(RESTY_IMAGE_BASE),src)
package-kong:
	@echo "nothing to be done"
else
package-kong: actual-package-kong
endif

actual-package-kong: build-kong
	@$(DOCKER_COMMAND) -f Dockerfile.package \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	--build-arg DOCKER_KONG_SUFFIX=$(DOCKER_KONG_SUFFIX) \
	--build-arg KONG_SHA=$(KONG_SHA) \
	--build-arg EDITION=$(EDITION) \
	--build-arg KONG_VERSION=$(KONG_VERSION) \
	--build-arg KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	--build-arg KONG_CONFLICTS=$(KONG_CONFLICTS) \
	--build-arg PRIVATE_KEY_FILE=kong.private.gpg-key.asc \
	--build-arg PRIVATE_KEY_PASSPHRASE="$(PRIVATE_KEY_PASSPHRASE)" \
	-t kong/kong-build-tools:kong-packaged-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_KONG_SUFFIX) .
ifeq ($(BUILDX),false)
	docker run -d --rm --name output kong/kong-build-tools:kong-packaged-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_KONG_SUFFIX) tail -f /dev/null
	docker cp output:/output/ output
	docker stop output
	mv output/output/*.$(PACKAGE_TYPE)* output/
	rm -rf output/*/
else
	docker buildx build --output output --platform linux/amd64,linux/arm64 -f Dockerfile.scratch \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	--build-arg DOCKER_KONG_SUFFIX=$(DOCKER_KONG_SUFFIX) \
	--build-arg KONG_SHA=$(KONG_SHA) .
	mv output/linux*/output/*.$(PACKAGE_TYPE)* output/
	rm -rf output/*/
endif

ifeq ($(RESTY_IMAGE_BASE),src)
build-kong:
	@echo "nothing to be done"
else
build-kong: actual-build-kong
endif

actual-build-kong:
	-rm -rf kong
	-cp -R $(KONG_SOURCE_LOCATION) kong
	$(CACHE_COMMAND) kong/kong-build-tools:kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_KONG_SUFFIX) || \
	( $(MAKE) build-openresty && \
	$(DOCKER_COMMAND) -f Dockerfile.kong \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	--build-arg DOCKER_OPENRESTY_SUFFIX=$(DOCKER_OPENRESTY_SUFFIX) \
	-t kong/kong-build-tools:kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_KONG_SUFFIX) . )
	-$(UPDATE_CACHE_COMMAND) kong/kong-build-tools:kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_KONG_SUFFIX)

kong-test-container:
ifneq ($(RESTY_IMAGE_BASE),src)
	$(CACHE_COMMAND) kong/kong-build-tools:test-$(DOCKER_TEST_SUFFIX) || \
	( $(MAKE) build-kong  && $(DOCKER_COMMAND) -f Dockerfile.test \
	--build-arg DOCKER_KONG_SUFFIX=$(DOCKER_KONG_SUFFIX) \
	--build-arg DOCKER_BASE_SUFFIX=$(DOCKER_BASE_SUFFIX) \
	--build-arg KONG_SHA=${KONG_SHA} \
	-t kong/kong-build-tools:test-$(DOCKER_TEST_SUFFIX) . )
	-$(UPDATE_CACHE_COMMAND) kong/kong-build-tools:test-$(DOCKER_TEST_SUFFIX)
	docker tag kong/kong-build-tools:test-$(DOCKER_TEST_SUFFIX) kong/kong-build-tools:test
endif

test-kong: kong-test-container
	docker-compose up -d
	bash -c 'while [[ "$$(docker-compose ps | grep healthy | wc -l)" != "3" ]]; do docker-compose ps && sleep 5; done'
	docker exec kong /kong/.ci/run_tests.sh

release-kong: test
	ARCHITECTURE=amd64 \
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	KONG_VERSION=$(KONG_VERSION) \
	BINTRAY_USR=$(BINTRAY_USR) \
	BINTRAY_KEY=$(BINTRAY_KEY) \
	PRIVATE_REPOSITORY=$(PRIVATE_REPOSITORY) \
	./release-kong.sh
ifeq ($(BUILDX),true)
	@ARCHITECTURE=arm64 \
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	KONG_VERSION=$(KONG_VERSION) \
	BINTRAY_USR=$(BINTRAY_USR) \
	BINTRAY_KEY=$(BINTRAY_KEY) \
	PRIVATE_REPOSITORY=$(PRIVATE_REPOSITORY) \
	./release-kong.sh
endif

test: setup-tests build-test-container
ifneq ($(RESTY_IMAGE_BASE),src)
	KONG_VERSION=$(KONG_VERSION) \
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	KONG_TEST_CONTAINER_TAG=$(KONG_TEST_CONTAINER_TAG) \
	KONG_TEST_CONTAINER_NAME=$(KONG_TEST_CONTAINER_NAME) \
	RESTY_VERSION=$(RESTY_VERSION) \
	RESTY_OPENSSL_VERSION=$(RESTY_OPENSSL_VERSION) \
	RESTY_LUAROCKS_VERSION=$(RESTY_LUAROCKS_VERSION) \
	RESTY_PCRE_VERSION=$(RESTY_PCRE_VERSION) \
	./test/run_tests.sh
endif

run_tests:
ifneq ($(RESTY_IMAGE_BASE),src)
	cd test && \
	$(CACHE_COMMAND) kong/kong-build-tools:test-runner-$(TEST_SHA) || \
	docker build -t kong/kong-build-tools:test-runner-$(TEST_SHA) -f Dockerfile.test_runner .
	cd test && \
	docker run -t --network host -e RESTY_VERSION=$(RESTY_VERSION) -e KONG_VERSION=$(KONG_VERSION) -e ADMIN_URI=$(TEST_ADMIN_URI) -e PROXY_URI=$(TEST_PROXY_URI) kong/kong-build-tools:test-runner-$(TEST_SHA) /bin/bash -c "py.test -p no:logging -p no:warnings test_*.tavern.yaml"
	-$(UPDATE_CACHE_COMMAND) kong/kong-build-tools:test-runner-$(TEST_SHA)
endif

develop-tests:
ifneq ($(RESTY_IMAGE_BASE),src)
	docker run -it --network host --rm -e RESTY_VERSION=$(RESTY_VERSION) -e KONG_VERSION=$(KONG_VERSION) \
	-e ADMIN_URI="https://`kubectl get nodes --namespace default -o jsonpath='{.items[0].status.addresses[0].address}'`:`kubectl get svc --namespace default kong-kong-admin -o jsonpath='{.spec.ports[0].nodePort}'`" \
	-e PROXY_URI="http://`kubectl get nodes --namespace default -o jsonpath='{.items[0].status.addresses[0].address}'`:`kubectl get svc --namespace default kong-kong-proxy -o jsonpath='{.spec.ports[0].nodePort}'`" \
	-v $$PWD/test:/app \
	kong/kong-build-tools:test-runner-$(TEST_SHA) /bin/bash
endif

build-test-container:
ifneq ($(RESTY_IMAGE_BASE),src)
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_VERSION=$(KONG_VERSION) \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	KONG_TEST_CONTAINER_NAME=$(KONG_TEST_CONTAINER_NAME) \
	test/build_container.sh
endif

setup-tests: cleanup-tests
ifneq ($(RESTY_IMAGE_BASE),src)
	./.ci/setup_kind.sh
endif

cleanup-tests:
ifneq ($(RESTY_IMAGE_BASE),src)
	-kind delete cluster
endif

cleanup: cleanup-tests cleanup-build
	-rm -rf kong
	-rm -rf openresty-build-tools
