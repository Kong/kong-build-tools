#!/bin/bash

set -e

kubectl apply -f https://github.com/Faithlife/minikube-registry-proxy/raw/master/kube-registry-proxy.yml
curl -L https://github.com/Faithlife/minikube-registry-proxy/raw/master/docker-compose.yml | MINIKUBE_IP=$(minikube ip) docker-compose -p mkr -f - up -d

while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' localhost:5000)" != 200 ]]; do
  sleep 5;
  echo "waiting for registry to be ready"
done  
  
RHEL=false
if [ "$RESTY_IMAGE_BASE" == "alpine" ]; then
  DOCKER_FILE="Dockerfile.alpine"
elif [ "$RESTY_IMAGE_BASE" == "ubuntu" ] || [ "$RESTY_IMAGE_BASE" == "debian" ]; then
  DOCKER_FILE="Dockerfile.deb"
elif [ "$RESTY_IMAGE_BASE" == "centos" ]; then
  DOCKER_FILE="Dockerfile.rpm"
  cp output/${KONG_PACKAGE_NAME}-${KONG_VERSION}.el${RESTY_IMAGE_TAG}.noarch.rpm output/kong.rpm
elif [ "$RESTY_IMAGE_BASE" == "amazonlinux" ]; then
  DOCKER_FILE="Dockerfile.rpm"
  cp output/${KONG_PACKAGE_NAME}-${KONG_VERSION}.aws.rpm output/kong.rpm
elif [ "$RESTY_IMAGE_BASE" == "rhel" ]; then
	docker pull registry.access.redhat.com/rhel${RESTY_IMAGE_TAG}
	docker tag registry.access.redhat.com/rhel${RESTY_IMAGE_TAG} rhel:${RESTY_IMAGE_TAG}
  DOCKER_FILE="Dockerfile.rpm"
  RHEL=true
else
  echo "Unrecognized base image $RESTY_IMAGE_BASE"
  exit 1
fi

docker build \
--build-arg RESTY_IMAGE_BASE=$RESTY_IMAGE_BASE \
--build-arg RESTY_IMAGE_TAG=$RESTY_IMAGE_TAG \
--build-arg KONG_VERSION=$KONG_VERSION \
--build-arg KONG_PACKAGE_NAME=$KONG_PACKAGE_NAME \
--build-arg RHEL=$RHEL \
--build-arg REDHAT_USERNAME=$REDHAT_USERNAME \
--build-arg REDHAT_PASSWORD=$REDHAT_PASSWORD \
-f test/$DOCKER_FILE \
-t localhost:5000/kong .

docker push localhost:5000/kong

helm init --wait
helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com/
helm install --dep-up --name kong --set image.repository=localhost,image.tag=5000/kong helm/stable/kong/

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
