#!/bin/bash
set -e

export KUBECONFIG=/root/.kube/config

# kubectl config view --minify # debug
# kubectl get ns #debug

# Add Helm repos

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update

# Deploy Prometheus stack
#helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
#  --namespace monitoring --create-namespace

# Deploy Kubecost
helm --debug --kubeconfig "$KUBECONFIG" upgrade --install kubecost kubecost/cost-analyzer \
     --namespace kubecost --create-namespace \
     --set kubecostToken="demo"

# Deploy sample pod (podinfo)
#helm upgrade --install podinfo podinfo/podinfo \
#  --namespace apps --create-namespace
