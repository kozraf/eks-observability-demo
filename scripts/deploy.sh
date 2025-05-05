#!/bin/bash
set -e

export KUBECONFIG=/root/.kube/config

# Add and update Helm repos
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update

# Install the AWS EBS CSI Driver and wait until ready
helm upgrade --install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system --create-namespace \
  --set controller.serviceAccount.create=true \
  --set controller.serviceAccount.name=ebs-csi-controller-sa \
  --set defaultStorageClass.enabled=true \
  --wait

# (Optional) Deploy Prometheus stack
# helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
#   --namespace monitoring --create-namespace

# Deploy Kubecost and wait for pods to be ready
helm upgrade --install kubecost kubecost/cost-analyzer \
  --namespace kubecost --create-namespace \
  --set kubecostToken="demo" 


# (Optional) Deploy sample pod
# helm upgrade --install podinfo podinfo/podinfo \
#   --namespace apps --create-namespace
