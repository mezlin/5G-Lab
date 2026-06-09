#!/bin/bash
echo "=========================================="
echo "Verifying 5G-Lab Prerequisites Setup"
echo "=========================================="

echo -e "\n[1] Checking Kubernetes Tools..."
kubectl version --client || echo "❌ kubectl not installed"
kubeadm version || echo "❌ kubeadm not installed"
kubelet --version || echo "❌ kubelet not installed"

echo -e "\n[2] Checking Helm..."
helm version || echo "❌ helm not installed"

echo -e "\n[3] Checking Containerd..."
containerd --version || echo "❌ containerd not installed"
systemctl is-active --quiet containerd && echo "✅ containerd is running" || echo "❌ containerd is NOT running"

echo -e "\n[4] Checking Swap..."
SWAP_USED=$(free -m | awk '/Swap/ {print $2}')
if [ "$SWAP_USED" == "0" ]; then
    echo "✅ Swap is disabled"
else
    echo "❌ Swap is NOT disabled!"
fi

echo -e "\n[5] Checking Kernel Modules..."
lsmod | grep overlay > /dev/null && echo "✅ overlay module loaded" || echo "❌ overlay module NOT loaded"
lsmod | grep br_netfilter > /dev/null && echo "✅ br_netfilter module loaded" || echo "❌ br_netfilter module NOT loaded"

echo -e "\n[6] Checking Additional Dependencies..."
python3 -m venv --help > /dev/null && echo "✅ python3-venv installed" || echo "❌ python3-venv NOT installed"
iperf3 -v > /dev/null && echo "✅ iperf3 installed" || echo "❌ iperf3 NOT installed"
ifconfig --version > /dev/null 2>&1 || ip --version > /dev/null && echo "✅ net-tools / iproute2 installed" || echo "❌ net-tools / iproute2 NOT installed"

echo -e "\n=========================================="
echo "Verification complete!"
echo "If you see '✅' and valid version numbers above, you are ready to initialize the cluster."
echo "=========================================="
