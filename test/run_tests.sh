#!/bin/bash

set -e

if [ "$RESTY_IMAGE_BASE" == "alpine" ]; then
  DOCKER_FILE="Dockerfile.alpine"
else
  echo "Unrecognized base image $RESTY_IMAGE_BASE"
  exit 1
fi

microk8s.docker build -f test/$DOCKER_FILE -t localhost:32000/kong .

while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' localhost:32000)" != 200 ]]; do
  echo "waiting for K8s registry to be ready"
  sleep 5;
done

microk8s.docker push localhost:32000/kong

helm init --wait
helm install --name kong --set image.repository=localhost,image.tag=32000/kong stable/kong

microk8s.kubectl get deployment kong-kong | tail -n +2 | awk '{print $5}'

while [[ "$(microk8s.kubectl get deployment kong-kong | tail -n +2 | awk '{print $5}')" != 1 ]]; do
  echo "waiting for Kong to be ready"
  sleep 5;
done

HOST="https://$(microk8s.kubectl get nodes --namespace default -o jsonpath='{.items[0].status.addresses[0].address}')"
echo $HOST
ADMIN_PORT=$(microk8s.kubectl get svc --namespace default kong-kong-admin -o jsonpath='{.spec.ports[0].nodePort}')
echo $ADMIN_PORT
PROXY_PORT=$(microk8s.kubectl get svc --namespace default kong-kong-proxy -o jsonpath='{.spec.ports[0].nodePort}')
echo $PROXY_PORT
CURL_COMMAND="curl -s -o /dev/null -w %{http_code} --insecure "
echo $CURL_COMMAND

if ! [ `$CURL_COMMAND$HOST:$ADMIN_PORT` == "200" ]; then
  echo "Can't invoke admin API"
  exit 1
fi

echo "Admin API passed"

RANDOM_API_NAME="randomapiname"
RESPONSE=`$CURL_COMMAND -d "name=$RANDOM_API_NAME&hosts=$RANDOM_API_NAME.com&upstream_url=http://mockbin.org" $HOST:$ADMIN_PORT/apis/`
if ! [ $RESPONSE == "201" ]; then
  echo "Can't create API"
  exit 1
fi

sleep 3

# Proxy Tests
RESPONSE=`$CURL_COMMAND -H "Host: $RANDOM_API_NAME.com" $HOST:$PROXY_PORT/request`
if ! [ $RESPONSE == "200" ]; then
  echo "Can't invoke API on HTTP"
  exit 1
fi

echo "Proxy and Admin smoke tests passed"
exit 0