#!/bin/bash

# This script configures CI systems such that they're capable of building our ARM64 assets

set -x

if [ "$RESTY_IMAGE_TAG" != "bionic" ] && [ "$RESTY_IMAGE_TAG" != "18.04" ] && [ "$RESTY_IMAGE_BASE" != "alpine" ]; then
    exit 0
fi

if uname -a | grep -qs -i darwin; then
    exit 0
fi

case "_$(uname -m)" in
_aarch64 | _arm64)
  friendly_arch='arm64'
  ;;
_amd64 | _x86_64 | _* | _)
  friendly_arch='amd64'
  ;;
esac

sudo apt-get install -y \
    qemu \
    binfmt-support \
    qemu-user-static

docker version
RESULT=$?
if [ "$RESULT" != "0" ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64,arm64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) test"
    sudo apt-get update
    sudo apt-get -y -o Dpkg::Options::="--force-confnew" install containerd.io docker-ce
fi

if test -d /etc/docker; then
    echo '{"experimental":true}' | sudo tee /etc/docker/daemon.json
fi

docker buildx version
RESULT=$?
if [ "$RESULT" != "0" ]; then
    latest="$(
        curl -fsSL https://github.com/docker/buildx/releases/latest \
            | grep -Eo 'href="/docker/buildx/releases/tag/([^"]+)' | uniq | tail -n1 | cut -d'/' -f6
    )"
    curl -fsSLo buildx "https://github.com/docker/buildx/releases/download/${latest}/buildx-${latest}.linux-${friendly_arch}"
    mkdir -p ~/.docker/cli-plugins/
    chmod +x buildx
    mv buildx ~/.docker/cli-plugins/docker-buildx
    sudo service docker restart
fi

set -e
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin || true
echo "$REDHAT_PASSWORD" | docker login -u "$REDHAT_USERNAME" registry.access.redhat.com --password-stdin || true
docker version
docker buildx version

export BUILDX=true

command -v ssh-agent >/dev/null || ( sudo apt-get update -y && sudo apt-get install openssh-client -y )
eval $(ssh-agent -s)
