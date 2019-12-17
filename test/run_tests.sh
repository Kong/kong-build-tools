#!/bin/bash

set -ex

if [[ "$RESTY_IMAGE_BASE" == "src" ]]; then
  exit 0
fi

USE_TTY="-t"
test -t 1 && USE_TTY="-it"

docker run ${USE_TTY} --rm ${KONG_TEST_CONTAINER_NAME} /bin/sh -c "/usr/local/kong/bin/openssl version" | grep -q ${RESTY_OPENSSL_VERSION}
docker run ${USE_TTY} --rm ${KONG_TEST_CONTAINER_NAME} /bin/sh -c "luarocks --version" | grep -q ${RESTY_LUAROCKS_VERSION}
docker run ${USE_TTY} --rm ${KONG_TEST_CONTAINER_NAME} /bin/sh -c "luarocks install version"
docker run ${USE_TTY} --rm ${KONG_TEST_CONTAINER_NAME} /bin/sh -c "luarocks config" | grep -q "/usr/local/openresty/luajit/bin/luajit"
docker run ${USE_TTY} --rm ${KONG_TEST_CONTAINER_NAME} /bin/sh -c "luarocks config" | grep -q "/usr/local/openresty/luajit/include/luajit-2.1"
docker run ${USE_TTY} --rm ${KONG_TEST_CONTAINER_NAME} /bin/sh -c "luarocks config" | grep -q "/usr/local/openresty/luajit/lib"
docker run ${USE_TTY} --rm ${KONG_TEST_CONTAINER_NAME} /bin/sh -c "ldd /usr/local/openresty/bin/openresty" | grep -q "/usr/local/kong/lib/libssl.so.1.1"
docker run ${USE_TTY} --rm ${KONG_TEST_CONTAINER_NAME} /bin/sh -c "ldd /usr/local/openresty/bin/openresty" | grep -q "/usr/local/kong/lib/libcrypto.so.1.1"
docker run ${USE_TTY} --rm ${KONG_TEST_CONTAINER_NAME} /bin/sh -c "ldd /usr/local/openresty/bin/openresty" | grep -q "/usr/local/openresty/luajit/lib/libluajit-5.1.so.2"
docker run ${USE_TTY} --rm ${KONG_TEST_CONTAINER_NAME} /bin/sh -c "/usr/local/openresty/bin/openresty -V" | grep "/work/pcre-${RESTY_PCRE_VERSION}"
docker run ${USE_TTY} --rm ${KONG_TEST_CONTAINER_NAME} /bin/sh -c "ls -la /usr/local/bin/go-pluginserver"

if [[ "$RESTY_IMAGE_TAG" == "bionic" ]]; then
    docker stop systemd-ubuntu || true
    docker rm -f systemd-ubuntu || true
    cp output/*.deb kong.deb
    docker run -d --rm --name systemd-ubuntu --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v $PWD:/src jrei/systemd-ubuntu
    docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "mkdir -p /etc/kong"
    docker cp test/kong_license.private systemd-ubuntu:/etc/kong/license.json
    docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "dpkg -i /src/kong.deb || true"
    docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "apt-get update"
    docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "apt-get install -f -y"
    docker exec ${USE_TTY} systemd-ubuntu /bin/bash -c "systemctl start kong"
    docker stop systemd-ubuntu
fi

export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"

while [[ "$(kubectl get pod --all-namespaces | grep -v Running | grep -v Completed | wc -l)" != 1 ]]; do
  kubectl get pod --all-namespaces -o wide
  echo "waiting for K8s to be ready"
  sleep 10;
done

kind load docker-image ${KONG_TEST_CONTAINER_NAME}

helm init --wait
helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com/
helm repo update

while [[ "$(kubectl get pod --all-namespaces | grep -v Running | grep -v Completed | wc -l)" != 1 ]]; do
  kubectl get pod --all-namespaces -o wide
  echo "waiting for K8s to be ready"
  sleep 10;
done

if [[ "$EDITION" == "enterprise" ]]; then
  kubectl create secret generic kong-enterprise-license --from-file=test/kong_license.private
  helm install --dep-up --version 0.14.2 --name kong --set image.repository=localhost,image.tag=${KONG_TEST_CONTAINER_TAG},enterprise.enabled=true stable/kong
else
  helm install --dep-up --version 0.14.2 --name kong --set image.repository=localhost,image.tag=${KONG_TEST_CONTAINER_TAG} stable/kong
fi

while [[ "$(kubectl get deployment kong-kong | tail -n +2 | awk '{print $4}')" != 1 ]]; do
  echo "waiting for Kong to be ready"
  kubectl get pod --all-namespaces -o wide
  sleep 10;
done

HOST="$(kubectl get nodes --namespace default -o jsonpath='{.items[0].status.addresses[0].address}')"
echo $HOST
ADMIN_PORT=$(kubectl get svc --namespace default kong-kong-admin -o jsonpath='{.spec.ports[0].nodePort}')
echo $ADMIN_PORT
PROXY_PORT=$(kubectl get svc --namespace default kong-kong-proxy -o jsonpath='{.spec.ports[0].nodePort}')
echo $PROXY_PORT

curl --insecure https://$HOST:$ADMIN_PORT/plugins -d name=kubernetes-sidecar-injector -d config.image=${KONG_TEST_CONTAINER_NAME}

TEST_ADMIN_URI=https://$HOST:$ADMIN_PORT TEST_PROXY_URI=http://$HOST:$PROXY_PORT make -f Makefile run_tests
