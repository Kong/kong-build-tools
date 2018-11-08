RESTY_IMAGE_BASE?=ubuntu
RESTY_IMAGE_TAG?=xenial

setup:
	sudo snap install microk8s --classic
	sudo snap install helm --classic
	sudo snap alias microk8s.kubectl kubectl
	sudo iptables -P FORWARD ACCEPT
	microk8s.enable storage dns registry
	/snap/bin/helm init

test: setup
	./run_tests.sh

clean:
	microk8s.reset
	sudo snap unalias kubectl
	sudo snap remove microk8s
	sudo snap remove helm
	
	
