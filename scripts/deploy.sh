#!/usr/bin/env bash
set -euo pipefail

# Minimal deploy script: bootstrap cluster add-ons (CSI Driver, optional monitoring) and install Argo CD

# Ensure necessary CLIs
for cmd in kubectl helm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd not found. Install $cmd and configure ~/.kube/config before running."
    exit 1
  fi
done

export KUBECONFIG=${KUBECONFIG:-$HOME/.kube/config}

# Add Helm repos
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm repo update

echo "Installing AWS EBS CSI Driver..."
helm upgrade --install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system --create-namespace \
  --set controller.serviceAccount.create=true \
  --set controller.serviceAccount.name=ebs-csi-controller-sa \
  --set defaultStorageClass.enabled=true


# Deploy Argo CD
echo "Deploying Argo CD..."
kubectl get ns argocd >/dev/null 2>&1 || kubectl create ns argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

echo "Waiting for Argo CD Server LoadBalancer address..."
LB_ADDR=""
for i in {1..30}; do
  LB_ADDR=$(kubectl get svc argocd-server -n argocd \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  LB_ADDR=${LB_ADDR:-$(kubectl get svc argocd-server -n argocd \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')}
  if [[ -n "$LB_ADDR" ]]; then break; fi
  echo -n "."; sleep 10
done

if [[ -z "$LB_ADDR" ]]; then
  echo "Error: LoadBalancer address not found."
  exit 1
fi

echo -e "\nCluster add-ons and Argo CD deployed."
echo "Argo CD URL: https://$LB_ADDR"
echo "Login: argocd login $LB_ADDR --username admin --password \$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo "Then update your password: argocd account update-password"
