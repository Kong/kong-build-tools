#!/bin/bash

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) test"
sudo apt-get update
sudo apt-get -y -o Dpkg::Options::="--force-confnew" install docker-ce
echo '{"experimental":true}' | sudo tee /etc/docker/daemon.json
curl -fsSLo buildx https://github.com/docker/buildx/releases/download/v0.2.2/buildx-v0.2.2.linux-amd64
mkdir -p ~/.docker/cli-plugins/
chmod +x buildx
mv buildx ~/.docker/cli-plugins/docker-buildx
sudo service docker restart
if [[ ! $RESTY_IMAGE_TAG == jessie ]] && [[ ! $PACKAGE_TYPE == rpm ]]; then 
	curl -L $DOCKER_MACHINE_URL/docker-machine-$(uname -s)-$(uname -m) >docker-machine
	sudo install docker-machine /usr/local/bin/docker-machine
	docker-machine version
fi
docker version
docker buildx version
