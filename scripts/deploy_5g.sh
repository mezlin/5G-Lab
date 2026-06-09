#!/bin/bash
set -e

echo "==============================================="
echo "5G Testbed Deployment Script"
echo "==============================================="

if [ "$EUID" -eq 0 ]; then
  echo "Please DO NOT run this script as root! Run it as your normal user."
  echo "The script will ask for sudo password when necessary."
  exit 1
fi

BASE_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$BASE_DIR"

echo "==============================================="
echo "[1/4] Initializing Kubernetes Cluster"
echo "==============================================="
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

echo "Setting up local kubeconfig..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Deploying Flannel CNI..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

echo "Untainting node for single-node deployment..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

echo "Waiting for node to be Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "==============================================="
echo "[2/4] Deploying Initial Namespaces & Monitoring"
echo "==============================================="
kubectl create namespace open5gs || true
kubectl create namespace monitoring || true

echo "Deploying Prometheus Monitoring..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -f manifests/prometheus/debug_kube-prometheus-values-nuc.yaml -n monitoring || echo "Prometheus might already be installed."

echo "Deploying Network Attachment Definitions..."
kubectl apply -k ./manifests/open5gs/networks5g/ -n open5gs

echo "==============================================="
echo "[3/4] Deploying Storage & MongoDB"
echo "==============================================="
echo "Deploying Longhorn..."
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.6.0/deploy/longhorn.yaml

echo "Deploying MongoDB..."
kubectl apply -k ./manifests/open5gs/mongodb/ -n open5gs

echo "Waiting for MongoDB pod to become Ready (this can take a few minutes)..."
sleep 10
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=mongodb -n open5gs --timeout=600s || echo "Timeout waiting for mongodb."

echo "Adding subscribers via mongo-tools..."
cd manifests/open5gs/mongo-tools/
if [ ! -d "../venv" ]; then
    python3 -m venv ../venv
fi
source ../venv/bin/activate
pip install bson pymongo
# Use modify-subscribers.py instead of modify_subscribers.py as the README had a typo
python3 ./modify-subscribers.py add
deactivate
cd "$BASE_DIR"

echo "==============================================="
echo "[4/4] Deploying Open5GS & srsRAN (gNB + UEs)"
echo "==============================================="
echo "Deploying Open5GS Core..."
kubectl apply -k ./manifests/open5gs/open5gs/ -n open5gs

echo "Deploying srsRAN gNB..."
kubectl apply -k ./manifests/srsRAN/srsran-gnb/ -n open5gs

echo "Deploying UEs..."
kubectl apply -k ./manifests/ues/srsue/ -n open5gs

echo "==============================================="
echo "Deployment Complete! ✅"
echo "==============================================="
echo "You can check the status of your pods with:"
echo "  kubectl get pods -n open5gs"
echo "  kubectl get pods -A"
echo "To view the AMF logs:"
echo "  k8s-log.sh amf open5gs"
echo ""
echo "Note: Make sure to start the UEs and GNU radio as described in the README (Step 4.2 & 4.3)"
