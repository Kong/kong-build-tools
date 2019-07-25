#!/bin/bash

if ! [ -x "$(command -v kind)" ]; then
    curl -Lo kind https://github.com/kubernetes-sigs/kind/releases/download/v0.4.0/kind-linux-amd64
    chmod +x ./kind
    mv kind $HOME/bin/
fi
if ! [ -x "$(command -v kubectl)" ]; then
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    mv kubectl $HOME/bin/
fi
kind create cluster
if ! [ -x "$(command -v helm)" ]; then
    curl -Lo get_helm.sh https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get
    chmod +x get_helm.sh
    sudo ./get_helm.shl
    rm -rf get_helm.sh
fi
export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller --upgrade
kubectl get nodes -o wide
kubectl get pods --all-namespaces -o wide
kubectl get services --all-namespaces -o wide
