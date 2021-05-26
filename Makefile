.PHONY: test build-kong

export SHELL:=/bin/bash

VERBOSE?=false
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
TEST_COMPOSE_PATH="$(PWD)/test/kong-tests-compose.yaml"

KONG_SOURCE_LOCATION?="$$PWD/../kong/"
EDITION?=`grep EDITION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
KONG_PACKAGE_NAME?="kong"
KONG_CONFLICTS?="kong-enterprise-edition"
KONG_LICENSE?="ASL 2.0"

PRIVATE_REPOSITORY?=true
KONG_TEST_CONTAINER_NAME=kong-tests
KONG_TEST_CONTAINER_TAG?=5000/kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)
KONG_TEST_IMAGE_NAME?=localhost:$(KONG_TEST_CONTAINER_TAG)
# This logic should mirror the kong-build-tools equivalent
KONG_VERSION?=`echo $(KONG_SOURCE_LOCATION)/kong-*.rockspec | sed 's,.*/,,' | cut -d- -f2`
RESTY_VERSION ?= `grep RESTY_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
KONG_GO_PLUGINSERVER_VERSION ?= `grep KONG_GO_PLUGINSERVER_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
RESTY_LUAROCKS_VERSION ?= `grep RESTY_LUAROCKS_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
RESTY_OPENSSL_VERSION ?= `grep RESTY_OPENSSL_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
RESTY_PCRE_VERSION ?= `grep RESTY_PCRE_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
KONG_GMP_VERSION ?= `grep KONG_GMP_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
KONG_NETTLE_VERSION ?= `grep KONG_NETTLE_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
KONG_NGINX_MODULE ?= `grep KONG_NGINX_MODULE $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
LIBYAML_VERSION ?= `grep LIBYAML_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
OPENRESTY_PATCHES ?= 1
DOCKER_KONG_VERSION = 'master'
DEBUG ?= 0
RELEASE_DOCKER_ONLY ?= false

DOCKER_MACHINE_ARM64_NAME?=docker-machine-arm64-${USER}

BUILDX?=false
ifndef AWS_ACCESS_KEY
	BUILDX=false
else ifeq ($(RESTY_IMAGE_TAG),xenial)
	BUILDX=true
else ifeq ($(RESTY_IMAGE_BASE),alpine)
	BUILDX=true
endif

BUILDX_INFO ?= $(shell docker buildx 2>&1 >/dev/null; echo $?)

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
DOCKER_OPENRESTY_SUFFIX=${BUILD_TOOLS_SHA}-${REQUIREMENTS_SHA}${OPENRESTY_PATCHES}${DEBUG}-${CACHE_BUSTER}
DOCKER_KONG_SUFFIX=${BUILD_TOOLS_SHA}${OPENRESTY_PATCHES}${DEBUG}-${KONG_VERSION}-${KONG_SHA}-${CACHE_BUSTER}
DOCKER_TEST_SUFFIX=${BUILD_TOOLS_SHA}-${DEBUG}-${KONG_SHA}-${CACHE_BUSTER}
OFFICIAL_RELEASE?=false

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

DOCKER_REPOSITORY?=mashape/kong-build-tools

debug:
	@echo ${CACHE}
	@echo ${BUILDX}
	@echo ${UPDATE_CACHE}
	@echo ${CACHE_COMMAND}
	@echo ${UPDATE_CACHE_COMMAND}
	@echo ${DOCKER_COMMAND}
	@echo ${BUILDX_INFO}
	@echo ${DEBUG}
	@echo ${KONG_NGINX_MODULE}

setup-ci: setup-build

setup-build:
	.ci/setup_ci.sh
ifeq ($(RESTY_IMAGE_BASE),src)
	@echo "nothing to be done"
else ifeq ($(BUILDX),true)
	docker buildx create --name multibuilder
	docker-machine create --driver amazonec2 \
	--amazonec2-instance-type a1.xlarge \
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
	$(CACHE_COMMAND) $(DOCKER_REPOSITORY):$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_BASE_SUFFIX) || \
	( $(DOCKER_COMMAND) -f dockerfiles/Dockerfile.$(PACKAGE_TYPE) \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	-t $(DOCKER_REPOSITORY):$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_BASE_SUFFIX) . )

build-openresty:
ifeq ($(RESTY_IMAGE_BASE),src)
	@echo "nothing to be done"
else
	-rm -rf kong
	-cp -R $(KONG_SOURCE_LOCATION) kong
	$(CACHE_COMMAND) $(DOCKER_REPOSITORY):openresty-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_OPENRESTY_SUFFIX) || \
	( $(MAKE) build-base ; \
	$(DOCKER_COMMAND) -f dockerfiles/Dockerfile.openresty \
	--build-arg RESTY_VERSION=$(RESTY_VERSION) \
	--build-arg RESTY_LUAROCKS_VERSION=$(RESTY_LUAROCKS_VERSION) \
	--build-arg RESTY_OPENSSL_VERSION=$(RESTY_OPENSSL_VERSION) \
	--build-arg RESTY_PCRE_VERSION=$(RESTY_PCRE_VERSION) \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	--build-arg DOCKER_REPOSITORY=$(DOCKER_REPOSITORY) \
	--build-arg DOCKER_BASE_SUFFIX=$(DOCKER_BASE_SUFFIX) \
	--build-arg LIBYAML_VERSION=$(LIBYAML_VERSION) \
	--build-arg EDITION=$(EDITION) \
	--build-arg KONG_GMP_VERSION=$(KONG_GMP_VERSION) \
	--build-arg KONG_NETTLE_VERSION=$(KONG_NETTLE_VERSION) \
	--build-arg KONG_NGINX_MODULE=$(KONG_NGINX_MODULE) \
	--build-arg OPENRESTY_PATCHES=$(OPENRESTY_PATCHES) \
	--build-arg DEBUG=$(DEBUG) \
	-t $(DOCKER_REPOSITORY):openresty-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_OPENRESTY_SUFFIX) . )
endif

ifeq ($(RESTY_IMAGE_BASE),src)
package-kong:
	@echo "nothing to be done"
else
package-kong: actual-package-kong
endif

actual-package-kong: cleanup setup-build
ifeq ($(DEBUG),1)
	exit 1
endif
	make build-kong
	@$(DOCKER_COMMAND) -f dockerfiles/Dockerfile.package \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	--build-arg DOCKER_REPOSITORY=$(DOCKER_REPOSITORY) \
	--build-arg DOCKER_KONG_SUFFIX=$(DOCKER_KONG_SUFFIX) \
	--build-arg KONG_SHA=$(KONG_SHA) \
	--build-arg EDITION=$(EDITION) \
	--build-arg KONG_VERSION=$(KONG_VERSION) \
	--build-arg KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	--build-arg KONG_CONFLICTS=$(KONG_CONFLICTS) \
	--build-arg PRIVATE_KEY_FILE=kong.private.gpg-key.asc \
	--build-arg PRIVATE_KEY_PASSPHRASE="$(PRIVATE_KEY_PASSPHRASE)" \
	-t $(DOCKER_REPOSITORY):kong-packaged-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_KONG_SUFFIX) .
ifeq ($(BUILDX),false)
	docker run -d --rm --name output $(DOCKER_REPOSITORY):kong-packaged-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_KONG_SUFFIX) tail -f /dev/null
	docker cp output:/output/ output
	docker stop output
	mv output/output/*.$(PACKAGE_TYPE)* output/
	rm -rf output/*/
else
	docker buildx build --output output --platform linux/amd64,linux/arm64 -f dockerfiles/Dockerfile.scratch \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	--build-arg DOCKER_REPOSITORY=$(DOCKER_REPOSITORY) \
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
	touch id_rsa.private
	-rm -rf kong
	-cp -R $(KONG_SOURCE_LOCATION) kong
	$(CACHE_COMMAND) $(DOCKER_REPOSITORY):kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_KONG_SUFFIX) || \
	( $(MAKE) build-openresty && \
	$(DOCKER_COMMAND) -f dockerfiles/Dockerfile.kong \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	--build-arg DOCKER_REPOSITORY=$(DOCKER_REPOSITORY) \
	--build-arg DOCKER_OPENRESTY_SUFFIX=$(DOCKER_OPENRESTY_SUFFIX) \
	-t $(DOCKER_REPOSITORY):kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_KONG_SUFFIX) . )

kong-test-container:
ifneq ($(RESTY_IMAGE_BASE),src)
	-rm -rf kong
	-cp -R $(KONG_SOURCE_LOCATION) kong
	$(CACHE_COMMAND) $(DOCKER_REPOSITORY):test-$(DOCKER_TEST_SUFFIX) || \
	( $(MAKE) build-openresty && \
	docker tag $(DOCKER_REPOSITORY):openresty-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_OPENRESTY_SUFFIX) \
	$(DOCKER_REPOSITORY):test-$(DOCKER_OPENRESTY_SUFFIX) && \
	$(DOCKER_COMMAND) -f test/Dockerfile.test \
	--build-arg KONG_GO_PLUGINSERVER_VERSION=$(KONG_GO_PLUGINSERVER_VERSION) \
	--build-arg DOCKER_REPOSITORY=$(DOCKER_REPOSITORY) \
	--build-arg DOCKER_OPENRESTY_SUFFIX=$(DOCKER_OPENRESTY_SUFFIX) \
	-t $(DOCKER_REPOSITORY):test-$(DOCKER_TEST_SUFFIX) . )
	
	docker tag $(DOCKER_REPOSITORY):test-$(DOCKER_TEST_SUFFIX) $(DOCKER_REPOSITORY):test
	
	-$(UPDATE_CACHE_COMMAND) $(DOCKER_REPOSITORY):test-$(DOCKER_TEST_SUFFIX)
endif

test-kong: kong-test-container
	docker-compose up -d
	bash -c 'healthy=$$(docker-compose ps | grep healthy | wc -l); while [[ "$$(( $$healthy ))" != "3" ]]; do docker-compose ps && sleep 5; done'
	docker exec kong /kong/.ci/run_tests.sh && make update-cache-images

release-kong: test
	ARCHITECTURE=amd64 \
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	KONG_VERSION=$(KONG_VERSION) \
	PULP_PROD_USR=$(PULP_PROD_USR) \
	PULP_PROD_PSW=$(PULP_PROD_PSW) \
	PULP_HOST_PROD=$(PULP_HOST_PROD) \
	PULP_STAGE_USR=$(PULP_STAGE_USR) \
	PULP_STAGE_PSW=$(PULP_STAGE_PSW) \
	PULP_HOST_STAGE=$(PULP_HOST_STAGE) \
	PRIVATE_REPOSITORY=$(PRIVATE_REPOSITORY) \
	RELEASE_DOCKER_ONLY=$(RELEASE_DOCKER_ONLY) \
	OFFICIAL_RELEASE=$(OFFICIAL_RELEASE) \
	DOCKER_LABEL_CREATED=`date -u +'%Y-%m-%dT%H:%M:%SZ'` \
	DOCKER_LABEL_REVISION=$(KONG_SHA) \
	./release-kong.sh
ifeq ($(BUILDX),true)
	@DOCKER_MACHINE_NAME=$(shell docker-machine env $(DOCKER_MACHINE_ARM64_NAME) | grep 'DOCKER_MACHINE_NAME=".*"' | cut -d\" -f2) \
	DOCKER_TLS_VERIFY=1 \
	DOCKER_HOST=$(shell docker-machine env $(DOCKER_MACHINE_ARM64_NAME) | grep 'DOCKER_HOST=".*"' | cut -d\" -f2) \
	DOCKER_CERT_PATH=$(shell docker-machine env $(DOCKER_MACHINE_ARM64_NAME) | grep 'DOCKER_CERT_PATH=".*"' | cut -d\" -f2) \
	ARCHITECTURE=arm64 \
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	KONG_VERSION=$(KONG_VERSION) \
	PULP_PROD_USR=$(PULP_PROD_USR) \
	PULP_PROD_PSW=$(PULP_PROD_PSW) \
	PULP_HOST_PROD=$(PULP_HOST_PROD) \
	PULP_STAGE_USR=$(PULP_STAGE_USR) \
	PULP_STAGE_PSW=$(PULP_STAGE_PSW) \
	PULP_HOST_STAGE=$(PULP_HOST_STAGE) \
	PRIVATE_REPOSITORY=$(PRIVATE_REPOSITORY) \
	RELEASE_DOCKER_ONLY=$(RELEASE_DOCKER_ONLY) \
	OFFICIAL_RELEASE=$(OFFICIAL_RELEASE) \
	DOCKER_LABEL_CREATED=`date -u +'%Y-%m-%dT%H:%M:%SZ'` \
	DOCKER_LABEL_REVISION=$(KONG_SHA) \
	./release-kong.sh
endif

test: build-test-container
ifneq ($(RESTY_IMAGE_BASE),src)
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	VERBOSE=$(VERBOSE) \
	KONG_VERSION=$(KONG_VERSION) \
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	PACKAGE_TYPE=$(PACKAGE_TYPE) \
	EDITION=$(EDITION) \
	KONG_TEST_CONTAINER_TAG=$(KONG_TEST_CONTAINER_TAG) \
	KONG_TEST_IMAGE_NAME=$(KONG_TEST_IMAGE_NAME) \
	RESTY_VERSION=$(RESTY_VERSION) \
	RESTY_OPENSSL_VERSION=$(RESTY_OPENSSL_VERSION) \
	RESTY_LUAROCKS_VERSION=$(RESTY_LUAROCKS_VERSION) \
	RESTY_PCRE_VERSION=$(RESTY_PCRE_VERSION) \
	CACHE_COMMAND="$(CACHE_COMMAND)" \
	UPDATE_CACHE_COMMAND="$(UPDATE_CACHE_COMMAND)" \
	TEST_SHA=$(TEST_SHA) \
	PACKAGE_LOCATION=$(PWD)/output \
	KONG_HOST=127.0.0.1 \
	KONG_ADMIN_PORT=8444 \
	KONG_PROXY_PORT=8000 \
	KONG_TEST_CONTAINER_NAME=$(KONG_TEST_CONTAINER_NAME) \
	KONG_ADMIN_URI="http://$(TEST_HOST):$(TEST_ADMIN_PORT)" \
	KONG_PROXY_URI="http://$(TEST_HOST):$(TEST_PROXY_PORT)" \
	TEST_COMPOSE_PATH=$(TEST_COMPOSE_PATH) \
	KONG_GO_PLUGINSERVER_VERSION=$(KONG_GO_PLUGINSERVER_VERSION) \
	./test/run_tests.sh && make update-cache-images
endif

develop-tests:
ifneq ($(RESTY_IMAGE_BASE),src)
	docker run -it --network host --rm -e RESTY_VERSION=$(RESTY_VERSION) -e KONG_VERSION=$(KONG_VERSION) \
	-e ADMIN_URI="http://127.0.0.1:8001" \
	-e PROXY_URI="http://127.0.0.1:8000" \
	-v $$PWD/test:/app \
	$(DOCKER_REPOSITORY):test-runner-$(TEST_SHA) /bin/bash
endif

build-test-container:
	touch test/kong_license.private
	ARCHITECTURE=amd64 \
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_VERSION=$(KONG_VERSION) \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	KONG_TEST_IMAGE_NAME=$(KONG_TEST_IMAGE_NAME) \
	DOCKER_KONG_VERSION=$(DOCKER_KONG_VERSION) \
	test/build_container.sh
ifeq ($(BUILDX),true)
	DOCKER_MACHINE_NAME=$(shell docker-machine env $(DOCKER_MACHINE_ARM64_NAME) | grep 'DOCKER_MACHINE_NAME=".*"' | cut -d\" -f2) \
	DOCKER_TLS_VERIFY=1 \
	DOCKER_HOST=$(shell docker-machine env $(DOCKER_MACHINE_ARM64_NAME) | grep 'DOCKER_HOST=".*"' | cut -d\" -f2) \
	DOCKER_CERT_PATH=$(shell docker-machine env $(DOCKER_MACHINE_ARM64_NAME) | grep 'DOCKER_CERT_PATH=".*"' | cut -d\" -f2) \
	ARCHITECTURE=arm64 \
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_VERSION=$(KONG_VERSION) \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	KONG_TEST_IMAGE_NAME=$(KONG_TEST_IMAGE_NAME) \
	DOCKER_KONG_VERSION=$(DOCKER_KONG_VERSION) \
	test/build_container.sh
endif

setup-tests: cleanup-tests
ifneq ($(RESTY_IMAGE_BASE),src)
	KONG_TEST_IMAGE_NAME=$(KONG_TEST_IMAGE_NAME) \
	KONG_TEST_CONTAINER_NAME=$(KONG_TEST_CONTAINER_NAME) \
		docker-compose -f test/kong-tests-compose.yaml up -d
	while ! curl localhost:8001; do \
		echo "Waiting for Kong to be ready..."; \
		sleep 5; \
	done
endif

cleanup-tests:
ifneq ($(RESTY_IMAGE_BASE),src)
	docker-compose -f test/kong-tests-compose.yaml down
	docker-compose -f test/kong-tests-compose.yaml rm -f
	docker volume prune -f
endif

cleanup: cleanup-tests cleanup-build
	-rm -rf kong
	-rm -rf docker-kong
	-rm -rf output/*

update-cache-images:
	-$(UPDATE_CACHE_COMMAND) $(DOCKER_REPOSITORY):$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_BASE_SUFFIX)
	-$(UPDATE_CACHE_COMMAND) $(DOCKER_REPOSITORY):openresty-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_OPENRESTY_SUFFIX)
	-$(UPDATE_CACHE_COMMAND) $(DOCKER_REPOSITORY):kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)-$(DOCKER_KONG_SUFFIX)
