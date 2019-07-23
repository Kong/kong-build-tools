#!/bin/bash

set -e

if [[ "$RESTY_IMAGE_BASE" == "src" ]]; then
  exit 0
fi

export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"
docker run -it --rm ${KONG_TEST_CONTAINER_NAME} /bin/sh -c "luarocks --version"

while [[ "$(kubectl get pods --all-namespaces -o wide | grep -v Running | wc -l)" != 1 ]]; do
  kubectl get pods --all-namespaces -o wide
  echo "waiting for K8s to be ready"
  sleep 10;
done

kind load docker-image ${KONG_TEST_CONTAINER_NAME}

helm init --wait
helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com/
helm repo update
helm install --dep-up --version 0.10.1 --name kong --set image.repository=localhost,image.tag=${KONG_TEST_CONTAINER_TAG} stable/kong

while [[ "$(kubectl get deployment kong-kong | tail -n +2 | awk '{print $4}')" != 1 ]]; do
  echo "waiting for Kong to be ready"
  kubectl get deployment kong-kong
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
