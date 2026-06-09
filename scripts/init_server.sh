#!/bin/bash
set -e

echo "==============================================="
echo "Installing prerequisites for 5G-Lab on Ubuntu 24.04"
echo "==============================================="

echo "Updating system..."
sudo apt-get update
sudo apt-get upgrade -y

echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "Setting up kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo "Setting up sysctl parameters for Kubernetes..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

echo "Installing containerd..."
sudo apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common
sudo apt-get install -y containerd

echo "Configuring containerd..."
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
# Configure containerd to use systemd as cgroup driver
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "Installing Kubernetes components (kubeadm, kubelet, kubectl)..."
# Adding the new pkgs.k8s.io repository
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "Installing Helm..."
curl -fsSL https://baltocdn.com/helm/signing.asc | sudo gpg --dearmor -o /usr/share/keyrings/helm.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install -y helm

echo "Installing additional dependencies (python3-venv, net-tools, etc.)..."
sudo apt-get install -y python3.12-venv iproute2 net-tools iperf3

echo "==========================================================="
echo "Installation of prerequisites is complete!"
echo "==========================================================="
echo ""
echo "To initialize the cluster as a control-plane node, run:"
echo "  sudo kubeadm init --pod-network-cidr=10.244.0.0/16"
echo ""
echo "Then setup your kubeconfig:"
echo "  mkdir -p \$HOME/.kube"
echo "  sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
echo "  sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
echo ""
echo "Deploy a CNI (e.g., Flannel):"
echo "  kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"
echo ""
echo "If you are running a single-node cluster (No separate worker nodes), untaint the node:"
echo "  kubectl taint nodes --all node-role.kubernetes.io/control-plane-"
echo "==========================================================="
