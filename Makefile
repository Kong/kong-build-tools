.PHONY: test build-kong

export SHELL:=/bin/bash

RESTY_IMAGE_BASE?=ubuntu
RESTY_IMAGE_TAG?=xenial
PACKAGE_TYPE?=deb
PACKAGE_TYPE?=debian

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

EDITION?="community"
KONG_PACKAGE_NAME?="kong"
KONG_CONFLICTS?="kong-enterprise-edition"
KONG_LICENSE?="ASL 2.0"
PRIVATE_REPOSITORY?=true
KONG_TEST_CONTAINER_NAME?=localhost:5000/kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)
KONG_SOURCE_LOCATION?="$$PWD/../kong/"
KONG_VERSION?=`echo $(KONG_SOURCE_LOCATION)/kong-*.rockspec | sed 's,.*/,,' | cut -d- -f2`
RESTY_VERSION ?= `grep RESTY_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
RESTY_LUAROCKS_VERSION ?= `grep RESTY_LUAROCKS_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
RESTY_OPENSSL_VERSION ?= `grep RESTY_OPENSSL_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
RESTY_PCRE_VERSION ?= `grep RESTY_PCRE_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
KONG_GMP_VERSION ?= `grep KONG_GMP_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
KONG_NETTLE_VERSION ?= `grep KONG_NETTLE_VERSION $(KONG_SOURCE_LOCATION)/.requirements | awk -F"=" '{print $$2}'`
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
LYAML_VERSION ?= 6.2.3

update-docker-cache:
ifneq ($(RESTY_IMAGE_BASE),rhel)
	-./docker_push_latest_if_changed.py --source kong/kong-build-tools:fpm
	-./docker_push_latest_if_changed.py --source kong/kong-build-tools:development || true
	-./docker_push_latest_if_changed.py --source kong/kong-build-tools:test_runner && echo "success!" || docker push kong/kong-build-tools:test_runner
	-./docker_push_latest_if_changed.py --source kong/kong-build-tools:$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) && echo "success!" || docker push kong/kong-build-tools:$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)
	-./docker_push_latest_if_changed.py --source kong/kong-build-tools:kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) && echo "success!" || docker push kong/kong-build-tools:kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)
	-docker tag $(KONG_TEST_CONTAINER_NAME) kong/kong-build-tools:test-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)
	-./docker_push_latest_if_changed.py --source kong/kong-build-tools:test-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) && echo "success!" || docker push kong/kong-build-tools:test-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)
endif

release-kong: test
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	KONG_VERSION=$(KONG_VERSION) \
	BINTRAY_USR=$(BINTRAY_USR) \
	BINTRAY_KEY=$(BINTRAY_KEY) \
	PRIVATE_REPOSITORY=$(PRIVATE_REPOSITORY) \
	./release-kong.sh

build-development-image:
ifeq ($(RESTY_IMAGE_TAG),xenial)
	docker pull kong/kong-build-tools:kong-ubuntu-xenial
	test -s output/kong-$(KONG_VERSION).xenial.all.deb || make package-kong
	cp output/kong-$(KONG_VERSION).xenial.all.deb output/kong-$(KONG_VERSION).kong-ubuntu-xenial.all.deb
	docker inspect --type=image kong/kong-build-tools:kong-ubuntu-xenial > /dev/null || make build-kong
	docker build \
	--cache-from kong/kong-build-tools:development \
	--build-arg RESTY_IMAGE_BASE=kong/kong-build-tools \
	--build-arg RESTY_IMAGE_TAG="kong-ubuntu-xenial" \
	--build-arg KONG_VERSION=$(KONG_VERSION) \
	--build-arg KONG_UID=$$(id -u) \
	--build-arg USER=$$USER \
	--build-arg RUNAS_USER=$$USER \
	-f test/Dockerfile.deb \
	-t kong/kong-build-tools:development .
endif

development: build-development-image
ifeq ($(RESTY_IMAGE_TAG),xenial)
	- docker-compose stop
	- docker-compose rm -f
	USER=$$(id -u) docker-compose up -d && \
	docker-compose exec kong make dev && \
	docker-compose exec kong /bin/bash
endif

package-kong: build-kong
	docker build -f Dockerfile.fpm \
	--cache-from kong/kong-build-tools:fpm \
	-t kong/kong-build-tools:fpm .
	docker run -t --rm \
	-v $$PWD/output/build:/tmp/build \
	-v $$PWD/output:/output \
	-e KONG_VERSION=$(KONG_VERSION) \
	-e KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	-e KONG_CONFLICTS=$(KONG_CONFLICTS) \
	-e KONG_LICENSE=$(KONG_LICENSE) \
	-e RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	-e RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	kong/kong-build-tools:fpm

build-kong:
	docker inspect --type=image kong/kong-build-tools:$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) > /dev/null || make build-base
	docker build -f Dockerfile.kong \
	--cache-from kong/kong-build-tools:kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) \
	--build-arg RESTY_VERSION=$(RESTY_VERSION) \
	--build-arg RESTY_LUAROCKS_VERSION=$(RESTY_LUAROCKS_VERSION) \
	--build-arg RESTY_OPENSSL_VERSION=$(RESTY_OPENSSL_VERSION) \
	--build-arg RESTY_PCRE_VERSION=$(RESTY_PCRE_VERSION) \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	--build-arg OPENSSL_EXTRA_OPTIONS=$(OPENSSL_EXTRA_OPTIONS) \
	--build-arg LIBYAML_VERSION=$(LIBYAML_VERSION) \
	--build-arg RESTY_CONFIG_OPTIONS=$(RESTY_CONFIG_OPTIONS) \
	--build-arg EDITION=$(EDITION) \
	--build-arg KONG_GMP_VERSION=$(KONG_GMP_VERSION) \
	--build-arg KONG_NETTLE_VERSION=$(KONG_NETTLE_VERSION) \
	-t kong/kong-build-tools:kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) .
	docker run -it --rm \
	-v $(KONG_SOURCE_LOCATION):/kong \
	-v $$PWD/output/build:/output/build \
	kong/kong-build-tools:kong-$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG)

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
	-t kong/kong-build-tools:$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) .
else
	docker build -f Dockerfile.$(PACKAGE_TYPE) \
	--cache-from kong/kong-build-tools:$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) \
	--build-arg RESTY_IMAGE_TAG="$(RESTY_IMAGE_TAG)" \
	--build-arg RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	-t kong/kong-build-tools:$(RESTY_IMAGE_BASE)-$(RESTY_IMAGE_TAG) .
endif

test: build_test_container
	KONG_VERSION=$(KONG_VERSION) \
	RESTY_IMAGE_BASE=$(RESTY_IMAGE_BASE) \
	RESTY_IMAGE_TAG=$(RESTY_IMAGE_TAG) \
	KONG_PACKAGE_NAME=$(KONG_PACKAGE_NAME) \
	./test/run_tests.sh

run_tests:
	cd test && docker build -t kong/kong-build-tools:test_runner --cache-from kong/kong-build-tools:test_runner -f Dockerfile.test_runner .
	docker run -it --network host -e RESTY_VERSION=$(RESTY_VERSION) -e KONG_VERSION=$(KONG_VERSION) -e ADMIN_URI=$(TEST_ADMIN_URI) -e PROXY_URI=$(TEST_PROXY_URI) ubuntu printenv
	docker run -it --network host -e RESTY_VERSION=$(RESTY_VERSION) -e KONG_VERSION=$(KONG_VERSION) -e ADMIN_URI=$(TEST_ADMIN_URI) -e PROXY_URI=$(TEST_PROXY_URI) kong/kong-build-tools:test_runner /bin/bash -c "py.test -p no:logging -p no:warnings test_*.tavern.yaml"

develop_tests:
	docker run -it --network host --rm -e RESTY_VERSION=$(RESTY_VERSION) -e KONG_VERSION=$(KONG_VERSION) \
	-e ADMIN_URI="https://`kubectl get nodes --namespace default -o jsonpath='{.items[0].status.addresses[0].address}'`:`kubectl get svc --namespace default kong-kong-admin -o jsonpath='{.spec.ports[0].nodePort}'`" \
	-e PROXY_URI="http://`kubectl get nodes --namespace default -o jsonpath='{.items[0].status.addresses[0].address}'`:`kubectl get svc --namespace default kong-kong-proxy -o jsonpath='{.spec.ports[0].nodePort}'`" \
	-v $$PWD/test:/app \
	kong:test_runner /bin/bash

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
	sudo apt-get update && sudo apt-get install -y socat
endif
	sudo minikube start --vm-driver none
	sudo minikube addons enable registry
	sudo chown -R $$USER $$HOME/.minikube
	sudo chgrp -R $$USER $$HOME/.minikube
	sudo chown -R $$USER $$HOME/.kube
	sudo chgrp -R $$USER $$HOME/.kube
	sudo minikube update-context
	until kubectl get nodes 2>&1 | sed -n 2p | grep -q Ready; do sleep 1 && kubectl get nodes; done
