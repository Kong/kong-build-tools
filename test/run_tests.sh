#!/bin/bash

set +e

kubectl apply -f https://github.com/Faithlife/minikube-registry-proxy/raw/master/kube-registry-proxy.yml
curl -L https://github.com/Faithlife/minikube-registry-proxy/raw/master/docker-compose.yml | MINIKUBE_IP=$(minikube ip) docker-compose -p mkr -f - up -d

while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' localhost:5000)" != 200 ]]; do
  curl -s -o /dev/null -w ''%{http_code}'' localhost:5000
  echo "waiting for registry to be ready"
  sleep 10;
done 

docker push localhost:5000/kong

helm init --wait
helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com/
helm repo update
helm install --dep-up --name kong --set image.repository=localhost,image.tag=5000/kong stable/kong

while [[ "$(kubectl get deployment kong-kong | tail -n +2 | awk '{print $4}')" != 1 ]]; do
  echo "waiting for Kong to be ready"
  sleep 10;
done

HOST="$(kubectl get nodes --namespace default -o jsonpath='{.items[0].status.addresses[0].address}')"
echo $HOST
ADMIN_PORT=$(kubectl get svc --namespace default kong-kong-admin -o jsonpath='{.spec.ports[0].nodePort}')
echo $ADMIN_PORT
PROXY_PORT=$(kubectl get svc --namespace default kong-kong-proxy -o jsonpath='{.spec.ports[0].nodePort}')
echo $PROXY_PORT

TEST_ADMIN_URI=https://$HOST:$ADMIN_PORT TEST_PROXY_URI=http://$HOST:$PROXY_PORT make -f Makefile run_tests
