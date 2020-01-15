echo $KONG_ADMIN_URI

# create route & service
curl -X POST $KONG_ADMIN_URI/services \
  --data name=test-service --data url=http://httpbin.org

curl -X POST $KONG_ADMIN_URI/services/test-service/routes \
  --data paths=/

curl -X POST $KONG_ADMIN_URI/plugins --data name=go-hello \
  --data config.message="hello from go!"

sleep 5

curl -i $KONG_PROXY_URI/anything

curl -I $KONG_PROXY_URI/anything | grep -i x-hello-from-go
