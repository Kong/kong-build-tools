#!/bin/bash

set -e

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) test"
sudo apt-get update
sudo apt-get -y -o Dpkg::Options::="--force-confnew" install containerd.io docker-ce
echo '{"experimental":true}' | sudo tee /etc/docker/daemon.json
curl -fsSLo buildx https://github.com/docker/buildx/releases/download/v0.2.2/buildx-v0.2.2.linux-amd64
mkdir -p ~/.docker/cli-plugins/
chmod +x buildx
mv buildx ~/.docker/cli-plugins/docker-buildx
sudo service docker restart
if ! [ -x "$(command -v docker-machine)" ]; then
	curl -L https://github.com/docker/machine/releases/download/v0.16.0/docker-machine-$(uname -s)-$(uname -m) >docker-machine
	sudo install docker-machine /usr/local/bin/docker-machine
fi
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true
echo "$REDHAT_PASSWORD" | docker login -u "$REDHAT_USERNAME" registry.access.redhat.com --password-stdin || true
docker-machine version
docker version
docker buildx version
