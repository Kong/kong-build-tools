#!/bin/bash

cp ../output/kong.*.tar.gz kong.apk.tar.gz && \
microk8s.docker build -f Dockerfile.alpine -t localhost:32000/kong . && \
microk8s.docker push localhost:32000/kong

helm init --wait
helm install --name kong --set image.repository=localhost,image.tag=32000/kong stable/kong

microk8s.kubectl get deployment kong-kong | tail -n +2 | awk '{print $5}'

while [[ "$(microk8s.kubectl get deployment kong-kong | tail -n +2 | awk '{print $5}')" != 1 ]]; do
  sleep 5;
  print "waiting for Kong to be available"
done

HOST="https://"$(kubectl get nodes --namespace default -o jsonpath='{.items[0].status.addresses[0].address}')
ADMIN_PORT=$(kubectl get svc --namespace default kong-kong-admin -o jsonpath='{.spec.ports[0].nodePort}')
PROXY_PORT=$(kubectl get svc --namespace default kong-kong-proxy -o jsonpath='{.spec.ports[0].nodePort}')
CURL_COMMAND="curl -s -o /dev/null -w %{http_code} --insecure "

if ! [ `$CURL_COMMAND$HOST:$ADMIN_PORT` == "200" ]; then
  echo "Can't invoke admin API"
  exit 1
fi

RANDOM_API_NAME=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
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