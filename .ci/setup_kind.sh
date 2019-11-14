#!/bin/bash

set -e
set -x

if ! [ -x "$(command -v kind)" ]; then
    curl -Lo kind https://github.com/kubernetes-sigs/kind/releases/download/v0.5.1/kind-linux-amd64
    chmod +x ./kind
    mv kind $HOME/bin/
fi
if ! [ -x "$(command -v kubectl)" ]; then
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    mv kubectl $HOME/bin/
fi
K8S_VERSION="${K8S_VERSION:-v1.15.3}"
kind create cluster --image "kindest/node:${K8S_VERSION}"
if ! [ -x "$(command -v helm)" ]; then
    curl -fsSLo get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get
    chmod +x get_helm.sh
    sudo DESIRED_VERSION=v2.16.1 ./get_helm.sh
    rm -rf get_helm.sh
fi
export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"

while [[ "$(kubectl get pod --all-namespaces | grep -v Running | grep -v Completed | wc -l)" != 1 ]]; do
  echo "waiting for K8s to be ready"
  sleep 10;
done

kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller --upgrade
kubectl get nodes -o wide
kubectl get pods --all-namespaces -o wide
kubectl get services --all-namespaces -o wide

while [[ "$(kubectl get pod --all-namespaces | grep -v Running | grep -v Completed | wc -l)" != 1 ]]; do
  echo "waiting for tiller to be ready"
  sleep 10;
done

kind version
kubectl version