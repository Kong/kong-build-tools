#!/bin/bash

set -e

kubectl apply -f https://github.com/Faithlife/minikube-registry-proxy/raw/master/kube-registry-proxy.yml
curl -L https://github.com/Faithlife/minikube-registry-proxy/raw/master/docker-compose.yml | MINIKUBE_IP=$(minikube ip) docker-compose -p mkr -f - up -d

while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' localhost:5000)" != 200 ]]; do
  sleep 5;
  echo "waiting for registry to be ready"
done 

docker push localhost:5000/kong

helm init --wait
helm update stable
helm install --dep-up --name kong --set ingressController.enabled=true --set image.repository=localhost,image.tag=5000/kong stable/kong

kubectl get deployment kong-kong | tail -n +2 | awk '{print $5}'

while [[ "$(kubectl get deployment kong-kong | tail -n +2 | awk '{print $5}')" != 1 ]]; do
  echo "waiting for Kong to be ready"
  sleep 5;
done

HOST="https://$(kubectl get nodes --namespace default -o jsonpath='{.items[0].status.addresses[0].address}')"
echo $HOST
ADMIN_PORT=$(kubectl get svc --namespace default kong-kong-admin -o jsonpath='{.spec.ports[0].nodePort}')
echo $ADMIN_PORT
PROXY_PORT=$(kubectl get svc --namespace default kong-kong-proxy -o jsonpath='{.spec.ports[0].nodePort}')
echo $PROXY_PORT
CURL_COMMAND="curl -s -o /tmp/out.txt -w %{http_code} --insecure "
echo $CURL_COMMAND

if ! [ `$CURL_COMMAND$HOST:$ADMIN_PORT` == "200" ]; then
  echo "Can't invoke admin API"
  exit 1
fi

echo "Admin API passed"

RANDOM_SERVICE_NAME="randomapiname"
RESPONSE=`$CURL_COMMAND -d "name=$RANDOM_SERVICE_NAME&url=http://mockbin.org" $HOST:$ADMIN_PORT/services`
if ! [ $RESPONSE == "201" ]; then
  echo "Can't create service"
  exit 1
fi

sleep 3

SERVICE_ID=$(cat /tmp/out.txt | sed 's,^.*"id":"\([^"]*\)".*$,\1,')
echo $SERVICE_ID
RESPONSE=`$CURL_COMMAND -d "hosts[]=$RANDOM_SERVICE_NAME.com&service.id=$SERVICE_ID" $HOST:$ADMIN_PORT/routes`
if ! [ $RESPONSE == "201" ]; then
  echo "Can't create service"
  exit 1
fi  

sleep 3

# Proxy Tests
RESPONSE=`$CURL_COMMAND -H "Host: $RANDOM_SERVICE_NAME.com" $HOST:$PROXY_PORT/request`
if ! [ $RESPONSE == "200" ]; then
  echo "Can't invoke API on HTTP"
  exit 1
fi

echo "Proxy and Admin smoke tests passed"
exit 0
