#!/bin/bash
# --- Configuration ---
REGION="us-east-1"
CLUSTER_NAME="otel-eks-cluster"

echo "Step 1: Installing kubectl..."
# Detect architecture (amd64 or arm64)
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; elif [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi

# Download the latest stable kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl # Clean up binary

# Verify kubectl
kubectl version --client --short || echo "kubectl installed successfully"

echo "--------------------------------"
echo "Step 2: Configuring EKS access..."
# Update kubeconfig to point to your cluster
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Test connection
kubectl get nodes || echo "Warning: Could not connect to cluster. Check your AWS credentials."

echo "--------------------------------"
echo "Step 3: Installing Helm..."
# Use the official Helm installer script
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh # Clean up script

# Verify Helm
helm version --short
