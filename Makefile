export SHELL:=/bin/bash
export SHELLOPTS:=$(if $(SHELLOPTS),$(SHELLOPTS):)pipefail:errexit

RESTY_IMAGE_BASE?=ubuntu
RESTY_IMAGE_TAG?=xenial
PACKAGE_TYPE?=deb
PACKAGE_TYPE?=debian
KONG_NETTLE_VERSION?=3.4
KONG_GMP_VERSION?=6.1.2
RESTY_VERSION?=1.13.6.2
RESTY_LUAROCKS_VERSION?=2.4.3
RESTY_OPENSSL_VERSION?=1.1.1
RESTY_PCRE_VERSION?=8.41

TEST_ADMIN_PROTOCOL?=http://
TEST_ADMIN_PORT?=8001
TEST_HOST?=localhost
TEST_ADMIN_URI?=$(TEST_ADMIN_PROTOCOL)$(TEST_HOST):$(TEST_ADMIN_PORT)
TEST_PROXY_PROTOCOL?=http://
TEST_PROXY_PORT?=8000
TEST_PROXY_URI?=$(TEST_PROXY_PROTOCOL)$(TEST_HOST):$(TEST_PROXY_PORT)

ifeq ($(RESTY_IMAGE_BASE),alpine)
	OPENSSL_EXTRA_OPTIONS=" -no-async"
endif

KONG_PACKAGE_NAME?="kong-community-edition"
KONG_CONFLICTS?="kong-enterprise-edition"
KONG_LICENSE?="ASL 2.0"
KONG_SOURCE_LOCATION?="$$PWD/../kong/"
KONG_VERSION?="0.0.0"
PRIVATE_REPOSITORY?=true
KONG_TEST_CONTAINER_NAME?=localhost:5000/kong

release-kong: test
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	KONG_VERSION=$(KONG_VERSION) \
	BINTRAY_USR=$(BINTRAY_USR) \
	BINTRAY_KEY=$(BINTRAY_KEY) \
	PRIVATE_REPOSITORY=$(PRIVATE_REPOSITORY) \
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
	docker pull registry.access.redhat.com/rhel${RESTY_IMAGE_TAG}
	docker tag registry.access.redhat.com/rhel${RESTY_IMAGE_TAG} rhel:${RESTY_IMAGE_TAG}
	PACKAGE_TYPE=rpm
	@docker build -f Dockerfile.$(PACKAGE_TYPE) \
	--build-arg RHEL=true \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	--build-arg REDHAT_USERNAME=$(REDHAT_USERNAME) \
	--build-arg REDHAT_PASSWORD=$(REDHAT_PASSWORD) \
	-t kong:$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) .
else
	docker build -f Dockerfile.$(PACKAGE_TYPE) \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	-t kong:$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) .
endif
	
.PHONY: test
test: build_test_container
	pushd test && \
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_VERSION=$(KONG_VERSION) \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	./run_tests.sh

run_tests:
	cd test && docker build -t kong:test_runner -f Dockerfile.test_runner .
	docker run -it -e ADMIN_URI=$(TEST_ADMIN_URI) -e PROXY_URI=$(TEST_PROXY_URI) kong:test_runner py.test test_smoke.tavern.yaml

build_test_container:
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_VERSION=$(KONG_VERSION) \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	KONG_TEST_CONTAINER_NAME=$(KONG_TEST_CONTAINER_NAME) \
	test/build_container.sh

cleanup_tests:
	-sudo minikube delete

setup_tests: cleanup_tests
ifeq (, $(shell which minikube))
	curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
	sudo cp minikube /usr/local/bin/
	sudo chmod 755 /usr/local/bin/minikube
	rm minikube
	curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
	sudo cp kubectl /usr/local/bin/
	sudo chmod 755 /usr/local/bin/kubectl
	rm kubectl
	curl -Lo get_helm.sh https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get
	chmod +x get_helm.sh
	sudo ./get_helm.sh
	rm -rf get_helm.sh
endif
	sudo minikube start --vm-driver none
	sudo minikube addons enable registry
	sudo chown -R $$USER $$HOME/.minikube
	sudo chgrp -R $$USER $$HOME/.minikube
	sudo minikube update-context
	until kubectl get nodes 2>&1 | sed -n 2p | grep -q Ready; do sleep 1 && kubectl get nodes; done
