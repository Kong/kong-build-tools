$(info starting make in kong-build-tools)

VARS_OLD := $(.VARIABLES)

.PHONY: test build-kong
.DEFAULT_GOAL := package-kong

export SHELL:=/bin/bash

VERBOSE?=false
RESTY_IMAGE_BASE?=ubuntu
RESTY_IMAGE_TAG?=20.04
PACKAGE_TYPE?=deb
PACKAGE_TYPE?=debian

SSL_PROVIDER?=openssl

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
ENABLE_KONG_LICENSING?=`grep ENABLE_KONG_LICENSING $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`

# this flag must be an empty string when EE_PORTS are undesired
KONG_EE_PORTS?=8002 8445 8003 8446 8004 8447
KONG_EE_PORTS_FLAG?=
ifeq ($(strip $(EDITION)),enterprise)
KONG_EE_PORTS_FLAG?=--build-arg EE_PORTS="$(KONG_EE_PORTS)"
endif

KONG_LICENSE?="ASL 2.0"

KONG_PACKAGE_NAME ?= `grep KONG_PACKAGE_NAME $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
OFFICIAL_RELEASE ?= true

PACKAGE_CONFLICTS ?= `grep PACKAGE_CONFLICTS $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
PACKAGE_PROVIDES ?= `grep PACKAGE_PROVIDES $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
PACKAGE_REPLACES ?= `grep PACKAGE_REPLACES $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
DOCKER_RELEASE_REPOSITORY?="kong/kong"

KONG_VERSION?=`./grep-kong-version.sh $(KONG_SOURCE_LOCATION)`
# If Kong is tagged, we want to use that as the release label, regardless of what the meta.lua file shows as the version
ifneq ($(KONG_TAG),)
KONG_RELEASE_LABEL=$(KONG_TAG)
else
KONG_RELEASE_LABEL=$(KONG_VERSION)
endif

KONG_TEST_CONTAINER_NAME=kong-tests
KONG_TEST_CONTAINER_TAG?=$(KONG_RELEASE_LABEL)-$(RESTY_IMAGE_BASE)
ADDITIONAL_TAG_LIST?=
KONG_TEST_IMAGE_NAME?=$(DOCKER_RELEASE_REPOSITORY):$(KONG_TEST_CONTAINER_TAG)

RESTY_VERSION ?= `grep RESTY_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
KONG_GO_PLUGINSERVER_VERSION ?= `grep KONG_GO_PLUGINSERVER_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
RESTY_LUAROCKS_VERSION ?= `grep RESTY_LUAROCKS_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
RESTY_OPENSSL_VERSION ?= `grep RESTY_OPENSSL_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
RESTY_BORINGSSL_VERSION ?= `grep RESTY_BORINGSSL_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
RESTY_PCRE_VERSION ?= `grep RESTY_PCRE_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
KONG_GMP_VERSION ?= `grep KONG_GMP_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
KONG_NETTLE_VERSION ?= `grep KONG_NETTLE_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
KONG_NGINX_MODULE ?= `grep KONG_NGINX_MODULE $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
RESTY_EVENTS ?= `grep RESTY_EVENTS $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
RESTY_LMDB ?= `grep RESTY_LMDB $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
ATC_ROUTER ?= `grep ATC_ROUTER $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
RESTY_WEBSOCKET ?= `grep RESTY_WEBSOCKET $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
OPENRESTY_PATCHES ?= 1
DOCKER_KONG_VERSION = '2.8.1'
DEBUG ?= 0
RELEASE_DOCKER_ONLY ?= false

DOCKER_MACHINE_ARM64_NAME?=docker-machine-arm64-${USER}

GITHUB_TOKEN ?=

# set to 'plain' to get less dynamic, but linear output from docker build(x)
DOCKER_BUILD_PROGRESS ?= auto

# whether to enable bytecompilation of kong lua files or not
ENABLE_LJBC ?= `grep ENABLE_LJBC $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`

# We build ARM64 for alpine and bionic only at this time
BUILDX?=false
ifndef AWS_ACCESS_KEY
	BUILDX=false
else ifeq ($(RESTY_IMAGE_TAG),bionic)
	BUILDX=true
else ifeq ($(RESTY_IMAGE_TAG),18.04)
	BUILDX=true
else ifeq ($(RESTY_IMAGE_BASE),alpine)
	BUILDX=true
endif

DOCKER_BUILDKIT ?= 1
DOCKER_LABELS?=--label org.opencontainers.image.version=$(KONG_VERSION) --label org.opencontainers.image.created=`date -u +'%Y-%m-%dT%H:%M:%SZ'` --label org.opencontainers.image.revision=$(KONG_SHA)

ifeq ($(BUILDX),false)
	DOCKER_COMMAND?=docker buildx build --progress=$(DOCKER_BUILD_PROGRESS) $(KONG_EE_PORTS_FLAG) --platform="linux/amd64" $(DOCKER_LABELS)
else
	DOCKER_COMMAND?=docker buildx build --progress=$(DOCKER_BUILD_PROGRESS) $(KONG_EE_PORTS_FLAG) --push --platform="linux/amd64,linux/arm64" $(DOCKER_LABELS)
endif

# Set this to unique value to bust the cache
CACHE_BUSTER?=0
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
TEST_SHA=$$(git log -1 --pretty=format:"%h" -- ${ROOT_DIR}/test/)${CACHE_BUSTER}

REQUIREMENTS_SHA=$$(find kong/distribution -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum  | cut -d' ' -f 1)
BUILD_TOOLS_SHA=$$(git rev-parse --short HEAD)
KONG_SHA=$$(git --git-dir=$(KONG_SOURCE_LOCATION)/.git rev-parse --short HEAD)

DOCKER_BASE_SUFFIX=${BUILD_TOOLS_SHA}${CACHE_BUSTER}
DOCKER_OPENRESTY_SUFFIX=${BUILD_TOOLS_SHA}-${REQUIREMENTS_SHA}${OPENRESTY_PATCHES}${DEBUG}-${CACHE_BUSTER}-${SSL_PROVIDER}
DOCKER_KONG_SUFFIX=${BUILD_TOOLS_SHA}${OPENRESTY_PATCHES}${DEBUG}-${KONG_VERSION}-${KONG_SHA}-${CACHE_BUSTER}-${SSL_PROVIDER}
DOCKER_TEST_SUFFIX=${BUILD_TOOLS_SHA}-${DEBUG}-${KONG_SHA}-${CACHE_BUSTER}

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

DOCKER_REPOSITORY?=kong/kong-build-tools

AWS_INSTANCE_TYPE ?= c5a.4xlarge
AWS_REGION ?= us-east-1
AWS_VPC ?= vpc-0316062370efe1cff

# us-east-1 bionic 18.04 amd64 hvm-ssd 20220308
AWS_AMI ?= ami-0d73480446600f555

# this prints out variables defined within this Makefile by filtering out
# from pre-existing ones ($VARS_OLD), then echoing both the unexpanded variable
# value (within single quotes) and the expanded variable value (without quotes)
#
# variables whose value does not expand are only printed once ("uniq"-ed )
debug:
	@$(foreach v, \
		$(sort $(filter-out $(VARS_OLD) VARS_OLD,$(.VARIABLES))), \
		( \
			echo '$(v) = $($(v))' ; echo \
			      $(v) = $($(v)) ;  \
		) | uniq ; \
	)

setup-ci: setup-build

setup-build:
	.ci/setup_ci.sh
	$(info 'running build: RESTY_IMAGE_BASE: $(RESTY_IMAGE_BASE)')
	$(info '               RESTY_IMAGE_TAG:  $(RESTY_IMAGE_TAG)')
ifeq ($(RESTY_IMAGE_BASE),src)
	@echo "nothing to be done"
else ifeq ($(BUILDX),true)
	docker buildx create --name multibuilder
	docker-machine create --driver amazonec2 \
	--amazonec2-instance-type $(AWS_INSTANCE_TYPE) \
	--amazonec2-region $(AWS_REGION) \
	--amazonec2-ami $(AWS_AMI) \
	--amazonec2-vpc-id $(AWS_VPC) \
	--amazonec2-monitoring \
	--amazonec2-tags created-by,${USER},created-via,kong-build-tools ${DOCKER_MACHINE_ARM64_NAME}
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

build-openresty: setup-kong-source
ifeq ($(RESTY_IMAGE_BASE),src)
	@echo "nothing to be done"
else
	-rm github-token
	$(CACHE_COMMAND) $(DOCKER_REPOSITORY):openresty-$(PACKAGE_TYPE)-$(DOCKER_OPENRESTY_SUFFIX) || \
	( \
		echo $$GITHUB_TOKEN > github-token; \
		docker pull --quiet $$(sed -ne 's;FROM \(.*$(PACKAGE_TYPE).*\) as.*;\1;p' dockerfiles/Dockerfile.openresty); \
		$(DOCKER_COMMAND) -f dockerfiles/Dockerfile.openresty \
		--secret id=github-token,src=github-token \
		--build-arg RESTY_VERSION=$(RESTY_VERSION) \
		--build-arg RESTY_LUAROCKS_VERSION=$(RESTY_LUAROCKS_VERSION) \
		--build-arg RESTY_OPENSSL_VERSION=$(RESTY_OPENSSL_VERSION) \
		--build-arg RESTY_BORINGSSL_VERSION=$(RESTY_BORINGSSL_VERSION) \
		--build-arg SSL_PROVIDER=$(SSL_PROVIDER) \
		--build-arg RESTY_PCRE_VERSION=$(RESTY_PCRE_VERSION) \
		--build-arg PACKAGE_TYPE=$(PACKAGE_TYPE) \
		--build-arg DOCKER_REPOSITORY=$(DOCKER_REPOSITORY) \
		--build-arg DOCKER_BASE_SUFFIX=$(DOCKER_BASE_SUFFIX) \
		--build-arg EDITION=$(EDITION) \
		--build-arg ENABLE_KONG_LICENSING=$(ENABLE_KONG_LICENSING) \
		--build-arg KONG_NGINX_MODULE=$(KONG_NGINX_MODULE) \
		--build-arg RESTY_LMDB=$(RESTY_LMDB) \
		--build-arg RESTY_WEBSOCKET=$(RESTY_WEBSOCKET) \
		--build-arg RESTY_EVENTS=$(RESTY_EVENTS) \
		--build-arg ATC_ROUTER=$(ATC_ROUTER) \
		--build-arg OPENRESTY_PATCHES=$(OPENRESTY_PATCHES) \
		--build-arg DEBUG=$(DEBUG) \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--cache-from $(DOCKER_REPOSITORY):openresty-$(PACKAGE_TYPE) \
		--cache-from kong/kong-build-tools:openresty-$(PACKAGE_TYPE) \
		-t $(DOCKER_REPOSITORY):openresty-$(PACKAGE_TYPE)-$(DOCKER_OPENRESTY_SUFFIX) . && \
		( \
			rm github-token || true \
		) \
	)
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
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	--build-arg RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	--build-arg PACKAGE_TYPE=$(PACKAGE_TYPE) \
	--build-arg DOCKER_REPOSITORY=$(DOCKER_REPOSITORY) \
	--build-arg DOCKER_KONG_SUFFIX=$(DOCKER_KONG_SUFFIX) \
	--build-arg KONG_SHA=$(KONG_SHA) \
	--build-arg EDITION=$(EDITION) \
	--build-arg KONG_VERSION=$(KONG_VERSION) \
	--build-arg KONG_RELEASE_LABEL=$(KONG_RELEASE_LABEL) \
	--build-arg KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	--build-arg PACKAGE_CONFLICTS=$(PACKAGE_CONFLICTS) \
	--build-arg PACKAGE_PROVIDES=$(PACKAGE_PROVIDES) \
	--build-arg PACKAGE_REPLACES=$(PACKAGE_REPLACES) \
	--build-arg SSL_PROVIDER=$(SSL_PROVIDER) \
	--build-arg PRIVATE_KEY_FILE=kong.private.gpg-key.asc \
	--build-arg PRIVATE_KEY_PASSPHRASE="$(PRIVATE_KEY_PASSPHRASE)" \
	-t $(DOCKER_REPOSITORY):kong-packaged-$(PACKAGE_TYPE)-$(DOCKER_KONG_SUFFIX) .
ifeq ($(BUILDX),false)
	docker run -d --rm --name output $(DOCKER_REPOSITORY):kong-packaged-$(PACKAGE_TYPE)-$(DOCKER_KONG_SUFFIX) tail -f /dev/null
	docker cp output:/output/ output
	docker stop output
	mv output/output/*.$(PACKAGE_TYPE)* output/
	rm -rf output/*/
else
	docker buildx build --progress=$(DOCKER_BUILD_PROGRESS) --output output --platform linux/amd64,linux/arm64 -f dockerfiles/Dockerfile.scratch \
	--build-arg PACKAGE_TYPE=$(PACKAGE_TYPE) \
	--build-arg DOCKER_REPOSITORY=$(DOCKER_REPOSITORY) \
	--build-arg DOCKER_KONG_SUFFIX=$(DOCKER_KONG_SUFFIX) \
	--build-arg KONG_SHA=$(KONG_SHA) .
	mv output/linux*/output/*.$(PACKAGE_TYPE)* output/
	rm -rf output/*/
endif
	@echo "Packaged Kong:"
	ls -al output/

ifeq ($(RESTY_IMAGE_BASE),src)
build-kong:
	@echo "nothing to be done"
else
build-kong: actual-build-kong
endif

kong-ci-cache-key:
	@echo "CACHE_KEY=$(DOCKER_OPENRESTY_SUFFIX)"

actual-build-kong: setup-kong-source
	touch id_rsa.private
	$(CACHE_COMMAND) $(DOCKER_REPOSITORY):kong-$(PACKAGE_TYPE)-$(DOCKER_KONG_SUFFIX) || \
	( $(MAKE) build-openresty && \
	-rm github-token; \
	echo $$GITHUB_TOKEN > github-token; \
	$(DOCKER_COMMAND) -f dockerfiles/Dockerfile.kong \
	--secret id=github-token,src=github-token \
	--build-arg PACKAGE_TYPE=$(PACKAGE_TYPE) \
	--build-arg DOCKER_REPOSITORY=$(DOCKER_REPOSITORY) \
	--build-arg DOCKER_OPENRESTY_SUFFIX=$(DOCKER_OPENRESTY_SUFFIX) \
	--build-arg ENABLE_LJBC=$(ENABLE_LJBC) \
	--build-arg BUILDKIT_INLINE_CACHE=1 \
	--build-arg SSL_PROVIDER=$(SSL_PROVIDER) \
	-t $(DOCKER_REPOSITORY):kong-$(PACKAGE_TYPE)-$(DOCKER_KONG_SUFFIX) . )
	-rm github-token

kong-test-container: setup-kong-source
ifneq ($(RESTY_IMAGE_BASE),src)
	$(CACHE_COMMAND) $(DOCKER_REPOSITORY):test-$(DOCKER_TEST_SUFFIX) || \
	( $(MAKE) build-openresty && \
	docker tag $(DOCKER_REPOSITORY):openresty-$(PACKAGE_TYPE)-$(DOCKER_OPENRESTY_SUFFIX) \
	$(DOCKER_REPOSITORY):test-$(DOCKER_OPENRESTY_SUFFIX) && \
	$(DOCKER_COMMAND) -f test/Dockerfile.test \
	--build-arg KONG_GO_PLUGINSERVER_VERSION=$(KONG_GO_PLUGINSERVER_VERSION) \
	--build-arg DOCKER_REPOSITORY=$(DOCKER_REPOSITORY) \
	--build-arg DOCKER_OPENRESTY_SUFFIX=$(DOCKER_OPENRESTY_SUFFIX) \
	--build-arg BUILDKIT_INLINE_CACHE=1 \
	--cache-from $(DOCKER_REPOSITORY):test \
	--cache-from kong/kong-build-tools:test \
	-t $(DOCKER_REPOSITORY):test-$(DOCKER_TEST_SUFFIX) . )

	docker tag $(DOCKER_REPOSITORY):test-$(DOCKER_TEST_SUFFIX) $(DOCKER_REPOSITORY):test

	-$(UPDATE_CACHE_COMMAND) $(DOCKER_REPOSITORY):test-$(DOCKER_TEST_SUFFIX)
endif

setup-kong-source:
	-rm -rf kong
	-cp -R $(KONG_SOURCE_LOCATION) kong
	-mkdir -pv kong/distribution
	-git submodule update --init --recursive
	-git submodule status
	-git -C kong submodule update --init --recursive
	-git -C kong submodule status
	cp kong/.requirements kong/distribution/.requirements

test-kong: kong-test-container
	docker-compose up -d
	bash -c 'healthy=$$(docker-compose ps | grep healthy | wc -l); while [[ "$$(( $$healthy ))" != "3" ]]; do docker-compose ps && sleep 5; done'
	docker exec kong /kong/.ci/run_tests.sh && make update-cache-images

release-kong-docker-images: test
ifeq ($(BUILDX),false)
	docker push $(KONG_TEST_IMAGE_NAME)
else
	docker push $(DOCKER_RELEASE_REPOSITORY):amd64-$(KONG_TEST_CONTAINER_TAG)
	docker push $(DOCKER_RELEASE_REPOSITORY):arm64-$(KONG_TEST_CONTAINER_TAG)
	docker manifest create $(KONG_TEST_IMAGE_NAME) -a \
		$(DOCKER_RELEASE_REPOSITORY):amd64-$(KONG_TEST_CONTAINER_TAG) \
		$(DOCKER_RELEASE_REPOSITORY):arm64-$(KONG_TEST_CONTAINER_TAG)
	docker manifest push $(KONG_TEST_IMAGE_NAME)
endif
	for ADDITIONAL_TAG in $(ADDITIONAL_TAG_LIST); do \
		docker run -t --rm \
			-v ~/.docker/config.json:/tmp/auth.json \
			quay.io/skopeo/stable:latest \
			copy --all docker://docker.io/$(KONG_TEST_IMAGE_NAME) \
			docker://docker.io/$(DOCKER_RELEASE_REPOSITORY):$$ADDITIONAL_TAG ; \
	done

release-kong: test
	ARCHITECTURE=amd64 \
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	KONG_VERSION=$(KONG_VERSION) \
	KONG_RELEASE_LABEL=$(KONG_RELEASE_LABEL) \
	PULP_PROD_USR=$(PULP_PROD_USR) \
	PULP_PROD_PSW=$(PULP_PROD_PSW) \
	PULP_HOST_PROD=$(PULP_HOST_PROD) \
	PULP_DEV_USR=$(PULP_DEV_USR) \
	PULP_DEV_PSW=$(PULP_DEV_PSW) \
	PULP_HOST_DEV=$(PULP_HOST_DEV) \
	EDITION=$(EDITION) \
	RELEASE_DOCKER_ONLY=$(RELEASE_DOCKER_ONLY) \
	DOCKER_RELEASE_REPOSITORY=$(DOCKER_RELEASE_REPOSITORY) \
	DOCKER_LABELS="$(DOCKER_LABELS)" \
	OFFICIAL_RELEASE=$(OFFICIAL_RELEASE) \
	PACKAGE_TYPE=$(PACKAGE_TYPE) \
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
	KONG_RELEASE_LABEL=$(KONG_RELEASE_LABEL) \
	PULP_PROD_USR=$(PULP_PROD_USR) \
	PULP_PROD_PSW=$(PULP_PROD_PSW) \
	PULP_HOST_PROD=$(PULP_HOST_PROD) \
	PULP_DEV_USR=$(PULP_DEV_USR) \
	PULP_DEV_PSW=$(PULP_DEV_PSW) \
	PULP_HOST_DEV=$(PULP_HOST_DEV) \
	RELEASE_DOCKER_ONLY=$(RELEASE_DOCKER_ONLY) \
	DOCKER_LABELS="$(DOCKER_LABELS)" \
	OFFICIAL_RELEASE=$(OFFICIAL_RELEASE) \
	PACKAGE_TYPE=$(PACKAGE_TYPE) \
	./release-kong.sh
endif
ifeq ($(RELEASE_DOCKER),true)
	make release-kong-docker-images
endif

test: build-test-container
ifneq ($(RESTY_IMAGE_BASE),src)
	CACHE_COMMAND="$(CACHE_COMMAND)" \
	EDITION=$(EDITION) \
	KONG_ADMIN_PORT=8444 \
	KONG_ADMIN_URI="http://$(TEST_HOST):$(TEST_ADMIN_PORT)" \
	KONG_GO_PLUGINSERVER_VERSION=$(KONG_GO_PLUGINSERVER_VERSION) \
	KONG_HOST=127.0.0.1 \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	KONG_PROXY_PORT=8000 \
	KONG_PROXY_URI="http://$(TEST_HOST):$(TEST_PROXY_PORT)" \
	KONG_SOURCE_LOCATION=$(KONG_SOURCE_LOCATION) \
	KONG_TEST_CONTAINER_NAME=$(KONG_TEST_CONTAINER_NAME) \
	KONG_TEST_CONTAINER_TAG=$(KONG_TEST_CONTAINER_TAG) \
	KONG_TEST_IMAGE_NAME=$(KONG_TEST_IMAGE_NAME) \
	KONG_VERSION=$(KONG_VERSION) \
	KONG_RELEASE_LABEL=$(KONG_RELEASE_LABEL) \
	PACKAGE_LOCATION=$(PWD)/output \
	PACKAGE_TYPE=$(PACKAGE_TYPE) \
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	RESTY_LUAROCKS_VERSION=$(RESTY_LUAROCKS_VERSION) \
	RESTY_OPENSSL_VERSION=$(RESTY_OPENSSL_VERSION) \
	RESTY_PCRE_VERSION=$(RESTY_PCRE_VERSION) \
	RESTY_VERSION=$(RESTY_VERSION) \
	SSL_PROVIDER=$(SSL_PROVIDER) \
	TEST_COMPOSE_PATH=$(TEST_COMPOSE_PATH) \
	TEST_HOST=$(TEST_HOST) \
	TEST_SHA=$(TEST_SHA) \
	UPDATE_CACHE_COMMAND="$(UPDATE_CACHE_COMMAND)" \
	VERBOSE=$(VERBOSE) \
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
ifneq ($(RESTY_IMAGE_BASE),src)
	touch test/kong_license.private
	ARCHITECTURE=amd64 \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	PACKAGE_TYPE=$(PACKAGE_TYPE) \
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_RELEASE_LABEL=$(KONG_RELEASE_LABEL) \
	DOCKER_RELEASE_REPOSITORY=$(DOCKER_RELEASE_REPOSITORY) \
	KONG_TEST_CONTAINER_TAG=$(KONG_TEST_CONTAINER_TAG) \
	DOCKER_KONG_VERSION=$(DOCKER_KONG_VERSION) \
	DOCKER_BUILD_PROGRESS=$(DOCKER_BUILD_PROGRESS) \
	DOCKER_LABELS="$(DOCKER_LABELS)" \
	EDITION="$(EDITION)" \
	test/build_container.sh
	docker tag $(DOCKER_RELEASE_REPOSITORY):amd64-$(KONG_TEST_CONTAINER_TAG) \
		$(DOCKER_RELEASE_REPOSITORY):$(KONG_TEST_CONTAINER_TAG)
	docker tag $(DOCKER_RELEASE_REPOSITORY):amd64-$(KONG_TEST_CONTAINER_TAG) \
		$(KONG_TEST_IMAGE_NAME)
ifeq ($(BUILDX),true)
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes && \
	ARCHITECTURE=arm64 \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	PACKAGE_TYPE=$(PACKAGE_TYPE) \
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_RELEASE_LABEL=$(KONG_RELEASE_LABEL) \
	DOCKER_RELEASE_REPOSITORY=$(DOCKER_RELEASE_REPOSITORY) \
	KONG_TEST_CONTAINER_TAG=$(KONG_TEST_CONTAINER_TAG) \
	DOCKER_KONG_VERSION=$(DOCKER_KONG_VERSION) \
	DOCKER_LABELS="$(DOCKER_LABELS)" \
	EDITION="$(EDITION)" \
	test/build_container.sh
endif
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
	docker stop user-validation-tests || true
	docker rm user-validation-tests || true
	docker volume prune -f
endif

cleanup: cleanup-tests cleanup-build
	-rm -rf kong
	-rm -rf docker-kong
	-rm -rf output/*
	-rm -f github-token
	-git submodule deinit -f .
	-docker rmi $(KONG_TEST_IMAGE_NAME)
	-docker rmi amd64-$(KONG_TEST_CONTAINER_TAG)
	-docker rmi arm64-$(KONG_TEST_CONTAINER_TAG)


update-cache-images:
ifeq ($(BUILDX),false)
	-$(UPDATE_CACHE_COMMAND) $(DOCKER_REPOSITORY):openresty-$(PACKAGE_TYPE)-$(DOCKER_OPENRESTY_SUFFIX)
	-docker tag $(DOCKER_REPOSITORY):openresty-$(PACKAGE_TYPE)-$(DOCKER_OPENRESTY_SUFFIX) $(DOCKER_REPOSITORY):openresty-$(PACKAGE_TYPE)
	-$(UPDATE_CACHE_COMMAND) $(DOCKER_REPOSITORY):openresty-$(PACKAGE_TYPE)
	-$(UPDATE_CACHE_COMMAND) $(DOCKER_REPOSITORY):kong-$(PACKAGE_TYPE)-$(DOCKER_KONG_SUFFIX)
	-docker tag $(DOCKER_REPOSITORY):kong-$(PACKAGE_TYPE)-$(DOCKER_KONG_SUFFIX) $(DOCKER_REPOSITORY):kong-$(PACKAGE_TYPE)
	-$(UPDATE_CACHE_COMMAND) $(DOCKER_REPOSITORY):kong-$(PACKAGE_TYPE)
	-$(UPDATE_CACHE_COMMAND) $(DOCKER_REPOSITORY):test
endif
