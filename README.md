# E2E Containerized O-RAN 5G Network with LLM Integration

> **An End-to-End Containerized O-RAN 5G Testbed featuring an LLM-powered AI Management Dashboard.**

### Open5GS + srsRAN ZMQ on Kubernetes — Ubuntu 24.04

> **Repository:** `https://github.com/mezlin/5G-Lab`
> **Stack:** Open5GS v2.7.0 · srsRAN ZMQ · GNU Radio · Kubernetes 1.30 · Longhorn · Prometheus + Grafana
> **Target:** Ubuntu 24.04, single-node Kubernetes cluster

---

## Table of Contents

1. [System Requirements](#1-system-requirements)
2. [Pre-Deployment: System Configuration](#2-pre-deployment-system-configuration)
3. [Step 1: Install containerd](#3-step-1-install-containerd)
4. [Step 2: Install Kubernetes Components](#4-step-2-install-kubernetes-components)
5. [Step 3: Initialize the Cluster](#5-step-3-initialize-the-cluster)
6. [Step 4: Install Helm](#6-step-4-install-helm)
7. [Step 5: Install Open vSwitch and CNI Plugins](#7-step-5-install-open-vswitch-and-cni-plugins)
8. [Step 6: Clone Repository and Configure PATH](#8-step-6-clone-repository-and-configure-path)
9. [Step 7: Deploy Monitoring Stack](#9-step-7-deploy-monitoring-stack)
10. [Step 8: Deploy Storage and MongoDB](#10-step-8-deploy-storage-and-mongodb)
11. [Step 9: Add Subscribers](#11-step-9-add-subscribers)
12. [Step 10: Deploy Open5GS Core](#12-step-10-deploy-open5gs-core)
13. [Step 11: Deploy srsRAN Pods and iperf](#13-step-11-deploy-srsran-pods-and-iperf)
14. [Step 12: Start the Radio Stack](#14-step-12-start-the-radio-stack)
15. [Step 13: Validate End-to-End Connectivity](#15-step-13-validate-end-to-end-connectivity)
16. [Checkpoint Summary](#16-checkpoint-summary)
17. [Known Errors and Solutions](#17-known-errors-and-solutions)

---

## 1. System Requirements

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 8 cores | 12+ cores |
| RAM | 10 GB | 16+ GB |
| Disk | 64 GB | 128 GB |
| OS | Ubuntu 24.04 | Ubuntu 24.04 |

---

## 2. Pre-Deployment: System Configuration

Every command in this section must be run before anything else.

### 2.1 Disable swap

Kubernetes requires swap to be disabled. If active, kubeadm init will fail.

```bash
sudo swapoff -a
free -h
# Swap line must show 0B / 0B / 0B
```

### 2.2 Load required kernel modules

`overlay` and `br_netfilter` are required by the container runtime and pod networking. `sctp` is required for the gNB to communicate with the AMF over N2 — without it the gNB will fail with a silent connection error.

Create the persistent load file:

```bash
sudo tee /etc/modules-load.d/k8s.conf > /dev/null <<EOF
overlay
br_netfilter
sctp
EOF
```

Load immediately in the current session:

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
sudo modprobe sctp
```

Verify all three are loaded:

```bash
lsmod | grep -E "overlay|br_netfilter|sctp"
# Must return three lines
```

### 2.3 Configure sysctl parameters

```bash
sudo tee /etc/sysctl.d/k8s.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
```

Set inotify limits. Without these, pods will crash with `failed to create fsnotify watcher: too many open files`:

```bash
sudo tee /etc/sysctl.d/99-inotify.conf > /dev/null <<EOF
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 524288
EOF
```

Apply all settings immediately:

```bash
sudo sysctl --system
```

Verify:

```bash
sysctl net.ipv4.ip_forward
# Must return: net.ipv4.ip_forward = 1
```

### 2.4 Install base utilities

```bash
sudo apt-get update
sudo apt-get install -y \
  curl wget git gnupg lsb-release \
  ca-certificates apt-transport-https software-properties-common \
  iproute2 net-tools jq \
  python3 python3-pip python3-venv \
  iperf3
```

> **Note on iperf3:** During installation Ubuntu may ask "Should iperf3 start as a daemon?" — answer **No**. iperf3 runs inside Kubernetes pods on demand in this testbed, not as a host service.

---

## 3. Step 1: Install containerd

> **Do not install containerd from Ubuntu's default repositories.** The version from `apt-get install containerd` is incompatible with Kubernetes 1.30. Always install from Docker's official repository.

### 3.1 Add Docker's GPG key

```bash
sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

### 3.2 Add Docker's apt repository

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
```

### 3.3 Install containerd

```bash
sudo apt-get install -y containerd.io
```

### 3.4 Generate the default configuration

```bash
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
```

### 3.5 Enable systemd cgroup driver

Ubuntu 24.04 uses cgroup v2 with systemd. containerd must be configured to match, otherwise kubelet will fail to manage container resources:

```bash
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
```

Verify the change:

```bash
grep "SystemdCgroup" /etc/containerd/config.toml
# Must return: SystemdCgroup = true
```

### 3.6 Start and enable containerd

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
sudo systemctl status containerd
# Must show: Active: active (running)
```

Verify the version (must be from Docker repo, not Ubuntu):

```bash
containerd --version
# Must show 1.7.x or 2.x
```

---

## 4. Step 2: Install Kubernetes Components

### 4.1 Add the Kubernetes apt repository

```bash
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
```

### 4.2 Install kubelet, kubeadm, and kubectl

```bash
sudo apt-get install -y kubelet kubeadm kubectl
```

Pin the versions to prevent automatic upgrades from breaking the cluster:

```bash
sudo apt-mark hold kubelet kubeadm kubectl
```

Verify:

```bash
kubeadm version
kubectl version --client
kubelet --version
```

---

## 5. Step 3: Initialize the Cluster

### 5.1 Initialize with kubeadm

The pod network CIDR `10.244.0.0/16` must match Flannel's default. Do not change it:

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

This takes 1–3 minutes.

### 5.2 Configure kubectl access

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Verify:

```bash
kubectl get nodes
# Shows the node in NotReady (CNI not installed yet)
```

### 5.3 Deploy Flannel CNI

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

### 5.4 Untaint the control-plane node

Required on single-node clusters so workload pods can be scheduled:

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
```

### 5.5 Wait for the node to become Ready

```bash
kubectl wait --for=condition=Ready nodes --all --timeout=300s

kubectl get nodes
# STATUS must show Ready

kubectl get pods -A
# All pods must show Running or Completed after ~2 minutes
```

---

## 6. Step 4: Install Helm

### 6.1 Download the Helm binary

Check `https://github.com/helm/helm/releases` for the latest stable release:

```bash
cd /tmp
curl -fsSL -o helm.tar.gz \
  https://get.helm.sh/helm-v3.16.4-linux-amd64.tar.gz
```

### 6.2 Extract and install

```bash
tar -zxvf helm.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
```

### 6.3 Clean up and verify

```bash
rm -rf /tmp/linux-amd64 /tmp/helm.tar.gz

helm version --short
# Must return: v3.16.x+...
```

---

## 7. Step 5: Install Open vSwitch and CNI Plugins

This step sets up the secondary network infrastructure that allows 5G pods to have multiple network interfaces (N2, N3, N4). This is mandatory — without it every Open5GS pod will be stuck in `Init 0/1`.

### 7.1 Install Open vSwitch

```bash
sudo apt-get update
sudo apt-get install -y openvswitch-switch

sudo systemctl status openvswitch-switch
# Must show: Active: active (running)
```

### 7.2 Create the three required OVS bridges

The Open5GS Network Attachment Definitions reference exactly these bridge names:

```bash
sudo ovs-vsctl --may-exist add-br n2br
sudo ovs-vsctl --may-exist add-br n3br
sudo ovs-vsctl --may-exist add-br n4br

sudo ip link set n2br up
sudo ip link set n3br up
sudo ip link set n4br up
```

Verify:

```bash
sudo ovs-vsctl show
# Must list n2br, n3br, n4br

ip link show n2br && ip link show n3br && ip link show n4br
# State must show UP for all three
```

### 7.3 Persist bridges across reboots

OVS bridges do not survive a reboot by default. Create a systemd service to recreate them automatically:

```bash
sudo tee /etc/systemd/system/open5gs-bridges.service > /dev/null <<'EOF'
[Unit]
Description=OVS bridges for Open5GS 5G testbed
After=openvswitch-switch.service
Requires=openvswitch-switch.service

[Service]
Type=oneshot
ExecStart=/usr/bin/ovs-vsctl --may-exist add-br n2br
ExecStart=/usr/bin/ovs-vsctl --may-exist add-br n3br
ExecStart=/usr/bin/ovs-vsctl --may-exist add-br n4br
ExecStart=/sbin/ip link set n2br up
ExecStart=/sbin/ip link set n3br up
ExecStart=/sbin/ip link set n4br up
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable open5gs-bridges.service

systemctl is-enabled open5gs-bridges.service
# Must return: enabled
```

### 7.4 Install Multus CNI

Multus is the meta-CNI plugin that enables pods to have multiple network interfaces:

```bash
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml

kubectl rollout status daemonset/kube-multus-ds -n kube-system --timeout=120s

kubectl get pods -n kube-system | grep multus
# Must show Running
```

### 7.5 Install the OVS-CNI binary

OVS-CNI is the plugin that Multus calls to attach pod interfaces to OVS bridges:

```bash
OVS_CNI_VER="v0.30.0"

curl -sL https://github.com/k8snetworkplumbingwg/ovs-cni/releases/download/${OVS_CNI_VER}/ovs-cni-amd64-${OVS_CNI_VER}.tar.gz \
  | tar -xz

sudo mv ovs-cni /opt/cni/bin/
sudo chmod +x /opt/cni/bin/ovs-cni
rm -f README.md

ls -la /opt/cni/bin/ovs-cni
# Must exist and be executable
```

Deploy the OVS-CNI DaemonSet:

```bash
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/ovs-cni/master/manifests/ovs-cni.yml
```

Final verification — all three must pass before continuing:

```bash
sudo ovs-vsctl show                              # lists n2br, n3br, n4br
kubectl get pods -n kube-system | grep multus    # Running
ls /opt/cni/bin/ovs-cni                         # exists
```

---

## 8. Step 6: Clone Repository and Configure PATH

```bash
cd ~
git clone https://github.com/mezlin/5G-Lab.git
cd 5G-Lab
```

Add the Kubernetes helper scripts to PATH:

```bash
echo "export PATH=\"$HOME/5G-Lab/scripts/k8s-helpers:\$PATH\"" >> ~/.bashrc
source ~/.bashrc
```

Verify:

```bash
which k8s-shell.sh
which k8s-log.sh
# Both must resolve to paths inside ~/5G-Lab/scripts/k8s-helpers/
```

---

## 9. Step 7: Deploy Monitoring Stack

### 9.1 Create namespaces

```bash
kubectl create namespace open5gs
kubectl create namespace monitoring
```

### 9.2 Add the Prometheus Helm repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 9.3 Install the Prometheus stack

```bash
cd ~/5G-Lab/manifests/prometheus/

helm install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  -f debug_kube-prometheus-values-nuc.yaml \
  -n monitoring
```

### 9.4 Wait for all monitoring pods

Do not proceed until every pod is Running:

```bash
kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=300s

kubectl get pods -n monitoring
# All pods must show Running
```

### 9.5 Retrieve Grafana credentials

The credentials in the README (`admin:prom-operator`) may not work — the values file overrides them. Always retrieve from the secret:

```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-user}" | base64 --decode; echo

kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode; echo
```

Grafana is accessible at `http://<vm-ip>:32000`. If using SSH:

```bash
ssh -L 32000:localhost:32000 user@your-server-ip
# Then open http://localhost:32000
```

---

## 10. Step 8: Deploy Storage and MongoDB

> **Critical ordering:** Longhorn must be completely ready before MongoDB is deployed. Deploying MongoDB first causes its PersistentVolumeClaim to stay Pending indefinitely because there is no StorageClass provisioner yet.

### 10.1 Deploy Network Attachment Definitions

NADs define the secondary networks that Multus uses to attach 5G interfaces to pods:

```bash
cd ~/5G-Lab/manifests/open5gs/
kubectl apply -k ./networks5g/ -n open5gs

kubectl get net-attach-def -n open5gs
# Must show: n2network, n3network, n4network
```

### 10.2 Deploy Longhorn

```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.6.0/deploy/longhorn.yaml
```

Wait for Longhorn manager pods (this takes 3–5 minutes):

```bash
kubectl wait --for=condition=Ready pod \
  -n longhorn-system \
  -l app=longhorn-manager \
  --timeout=600s
```

Wait for the CRD to be established:

```bash
kubectl wait --for=condition=Established \
  crd/volumes.longhorn.io \
  --timeout=120s
```

Verify the StorageClass exists before continuing:

```bash
kubectl get storageclass
# Must show a row with NAME=longhorn
```

### 10.3 Deploy MongoDB

Only after the above verification passes:

```bash
cd ~/5G-Lab/manifests/open5gs/
kubectl apply -k ./mongodb/ -n open5gs

kubectl wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=mongodb \
  -n open5gs \
  --timeout=600s

kubectl get pods -n open5gs | grep mongodb
# Must show: mongodb-0   1/1   Running
```

---

## 11. Step 9: Add Subscribers

Subscribers are the UE identities stored in MongoDB. Without them, the UE fails authentication and never attaches.

### 11.1 Set up the Python virtual environment

```bash
cd ~/5G-Lab/manifests/open5gs/mongo-tools/

python3 -m venv ../venv
source ../venv/bin/activate
```

### 11.2 Install pymongo

> **Install ONLY pymongo — never the standalone `bson` package.** Installing `bson` alongside `pymongo` causes conflicts that break the subscriber script with `ImportError: cannot import name 'SON' from 'bson'`.

```bash
pip install "pymongo==4.6.3"
```

Verify before running the script:

```bash
python3 -c "from bson.objectid import ObjectId; print('OK')"
# Must print: OK
```

### 11.3 Run the subscriber script

```bash
python3 ./modify-subscribers.py add
```

If you get a MongoDB connection error, port-forward MongoDB in a separate terminal:

```bash
kubectl port-forward -n open5gs svc/mongodb 27017:27017 &
python3 ./modify-subscribers.py add
```

### 11.4 Deactivate the virtual environment

```bash
deactivate
```

---

## 12. Step 10: Deploy Open5GS Core

### 12.1 Deploy all Network Functions

```bash
cd ~/5G-Lab/manifests/open5gs/open5gs/
kubectl apply -k . -n open5gs
```

### 12.2 Monitor pod startup

```bash
kubectl get pods -n open5gs -w
```

Wait until all NFs reach `Running 1/1`. Expected pods: AMF, SMF1, SMF2, UPF1, UPF2, NRF, SCP, AUSF, UDM, UDR, PCF, NSSF, BSF.

> If any pod is stuck in `Init 0/1`, the OVS bridges are missing or Multus is not running. Verify `sudo ovs-vsctl show` lists all three bridges.

### 12.3 Verify the AMF is healthy

```bash
k8s-log.sh amf open5gs | tail -30
```

The AMF is healthy when you see:

```
[amf]  INFO: ngap_server() [10.10.3.200]:38412
[sbi]  INFO: NF registered [Heartbeat:10s]
```

---

## 13. Step 11: Deploy srsRAN Pods and iperf

### 13.1 Deploy the gNB pod

```bash
cd ~/5G-Lab/manifests/srsRAN/srsran-gnb/
kubectl apply -k . -n open5gs
```

### 13.2 Deploy the UE pods

```bash
cd ~/5G-Lab/manifests/ues/srsue/
kubectl apply -k . -n open5gs
```

### 13.3 Deploy iperf

```bash
cd ~/5G-Lab/manifests/iperf/
kubectl apply -k . -n open5gs
```

### 13.4 Wait for pods to be Running

On a fresh VM, srsRAN images are ~2–3 GB and take 5–15 minutes to pull. This is normal and only happens once — containerd caches the images:

```bash
kubectl get pods -n open5gs -w
```

All pods must show Running before proceeding:

```
srsran-gnb-xxx   2/2   Running
srsran-ue1-xxx   1/1   Running
iperf2-server    1/1   Running
```

---

## 14. Step 12: Start the Radio Stack

> **This step must be repeated every time the VM reboots.**
> **The startup order is strict. Wait for each step's confirmation before moving to the next.**

Open four separate terminal windows.

---

### Terminal 1 — Start the gNB

```bash
k8s-shell.sh gnb open5gs
/srsran/config/start_gnb.sh
```

**Wait for both of these lines before opening Terminal 2:**

```
Cell pci=1, bw=10MHz, dl_arfcn=368500, dl_freq=1842.5 MHz, ...
NG Setup Response
```

`NG Setup Response` confirms the gNB connected to the AMF over N2. Leave this terminal open.

---

### Terminal 2 — Start the UE

```bash
k8s-shell.sh ue1 open5gs
/srsran/config/start_ue.sh 1
```

**Wait for these lines before opening Terminal 3:**

```
Random Access Complete.     c-rnti=0x4601, ta=0
RRC Connected
PDU Session Establishment successful. IP: 10.41.0.x
```

`PDU Session Establishment successful` confirms the UE is registered and has an IP address. Leave this terminal open.

---

### Terminal 3 — Start the GNU Radio broker

Two requirements that must both be met before running:

1. The script must be run from inside `/`. Running from any other directory causes `python3: can't open file './multi_ue_scenario.py': No such file or directory` because the script uses a relative path.
2. The GNU Radio prefs file must exist. Without it you get `vmcircbuf_createfilemapping: createfilemapping is not available`.

```bash
k8s-shell.sh ue1 open5gs

# Create the GNU Radio prefs file (required on every fresh container start)
mkdir -p /root/.gnuradio/prefs
echo "mmap_shm_open" > /root/.gnuradio/prefs/vmcircbuf_default_factory

# Navigate to the correct directory — mandatory
cd /srsran/config

# Start the broker (1 = number of UEs)
./start_gnu.sh 1
```

**Expected output:**

```
Press Enter to quit
```

> **Do not press Enter.** This is not an error — it means GNU Radio is running correctly. The ZMQ I/Q broker is active in the background. Pressing Enter immediately kills the broker, drops the radio link, and the UE loses connectivity. Leave this terminal open and untouched.

---

### Terminal 4 — Add the route and test

```bash
k8s-shell.sh ue1 open5gs
/srsran/config/add_route.sh
```

> Errors like `Cannot open network namespace "ue2"` and `Error: Nexthop has invalid gateway` for UEs 2–10 are normal when only UE1 is running. The route for UE1 is installed correctly.

---

## 15. Step 13: Validate End-to-End Connectivity

All validation must use `ip netns exec ue1`. Running plain `ping` inside the pod uses the Kubernetes pod network (`eth0`) and bypasses the 5G stack entirely. Only `ip netns exec ue1` sends traffic through the 5G tunnel (`tun_srsue`).

### 15.1 Verify the route

```bash
ip netns exec ue1 ip route
# Must show: default via 10.41.0.1 dev tun_srsue
```

### 15.2 Test connectivity through the 5G tunnel

```bash
ip netns exec ue1 ping -c 4 8.8.8.8
```

Expected:

```
64 bytes from 8.8.8.8: icmp_seq=1 ttl=126 time=350 ms
4 packets transmitted, 4 received, 0% packet loss
```

Latency of 250–650 ms is expected for a ZMQ software radio testbed.

### 15.3 Test DNS resolution

```bash
ip netns exec ue1 ping -c 4 google.ca
```

### 15.4 Test with iperf

Start the iperf server inside the UE network namespace:

```bash
ip netns exec ue1 iperf -s -u -p 5201
```

In a separate terminal, run the client from the iperf pod:

```bash
kubectl exec -n open5gs iperf2-server -- \
  iperf -c 10.41.0.3 -p 5201 -t 30 -b 2M -u
```

> Use the actual UE IP from the PDU Session Establishment line. Usable throughput is 1–3 Mbps — this is a known ZMQ/GNU Radio software limit, not a configuration error.

---

## 16. Checkpoint Summary

| Step | Verification command | Expected result |
|---|---|---|
| containerd | `containerd --version` | Shows 1.7.x+ from Docker repo |
| K8s cluster | `kubectl get nodes` | STATUS = Ready |
| Flannel | `kubectl get pods -n kube-flannel` | Running |
| OVS bridges | `sudo ovs-vsctl show` | Lists n2br, n3br, n4br |
| Multus | `kubectl get pods -n kube-system \| grep multus` | Running |
| OVS-CNI binary | `ls /opt/cni/bin/ovs-cni` | File exists |
| Monitoring | `kubectl get pods -n monitoring` | All Running |
| NADs | `kubectl get net-attach-def -n open5gs` | 3 NADs listed |
| Longhorn | `kubectl get storageclass` | Shows longhorn |
| MongoDB | `kubectl get pods -n open5gs \| grep mongodb` | 1/1 Running |
| Core NFs | `kubectl get pods -n open5gs` | All 13 NFs Running |
| AMF | `k8s-log.sh amf open5gs` | Shows ngap_server() :38412 |
| UE attached | UE terminal | PDU Session Establishment successful |
| GNU Radio | GNU Radio terminal | Press Enter to quit |
| E2E | `ip netns exec ue1 ping -c 4 8.8.8.8` | 4 packets received |

---

## 17. Known Errors and Solutions

---

### E01 — Pods stuck in `Init 0/1`: `failed to find bridge n3br`

**Symptom:**
```
Warning  FailedCreatePodSandBox: failed to find bridge n3br
```

**Cause:** OVS bridges do not exist on the host when Multus tries to attach pod interfaces.

**Solution:**
```bash
sudo ovs-vsctl --may-exist add-br n2br
sudo ovs-vsctl --may-exist add-br n3br
sudo ovs-vsctl --may-exist add-br n4br
sudo ip link set n2br up
sudo ip link set n3br up
sudo ip link set n4br up
```
Pods recover within 30–60 seconds automatically. Enable the systemd persistence service (Step 7.3) to prevent recurrence on reboot.

---

### E02 — `failed to create fsnotify watcher: too many open files`

**Symptom:** Appears in AMF or other NF pod logs.

**Cause:** Linux inotify instance limit is too low for a Kubernetes node with many pods.

**Solution:**
```bash
sudo sysctl -w fs.inotify.max_user_instances=8192
sudo sysctl -w fs.inotify.max_user_watches=524288
```
For persistence, add these to `/etc/sysctl.d/99-inotify.conf` as shown in Section 2.4.

---

### E03 — gNB: `failed to create SCTP gateway`

**Symptom:** Running `start_gnb.sh` exits immediately with an SCTP error.

**Cause:** SCTP kernel module is not loaded.

**Solution:**
```bash
sudo modprobe sctp
lsmod | grep sctp
```
For persistence, ensure `sctp` is in `/etc/modules-load.d/k8s.conf` as shown in Section 2.3.

---

### E04 — gNB: `connection timed out` to AMF

**Symptom:** gNB starts and SCTP is loaded, but cannot reach `10.10.3.200:38412`.

**Cause (most common):** The gNB pod was scheduled before OVS bridges existed. Multus never attached the N2 interface so the pod cannot reach AMF.

**Diagnosis:**
```bash
GNB_POD=$(kubectl get pod -n open5gs -l app=srsran-gnb \
  -o jsonpath='{.items[0].metadata.name}')

# Check for N2 interface
kubectl exec -n open5gs $GNB_POD -c gnb -- ip addr show
# Must show an interface with IP in 10.10.3.x range

# Test reachability
kubectl exec -n open5gs $GNB_POD -c gnb -- ping -c 3 10.10.3.200
```

**Solution — if N2 interface is missing:**
```bash
sudo ovs-vsctl show   # verify bridges exist first
kubectl rollout restart deployment -n open5gs srsran-gnb
kubectl get pods -n open5gs -w
```

**Solution — if ping succeeds but SCTP fails (iptables blocking):**
```bash
sudo iptables -I FORWARD -p sctp -j ACCEPT
sudo iptables -I INPUT   -p sctp -j ACCEPT
sudo iptables -I OUTPUT  -p sctp -j ACCEPT
```

---

### E05 — MongoDB PVC stuck in `Pending`

**Symptom:** `kubectl get pvc -n open5gs` shows STATUS = Pending. MongoDB pod never starts.

**Cause:** MongoDB was deployed before Longhorn's StorageClass was registered.

**Solution:**
```bash
kubectl get storageclass   # confirm longhorn now exists

kubectl delete pvc -n open5gs --all
kubectl delete pod -n open5gs -l app.kubernetes.io/name=mongodb

cd ~/5G-Lab/manifests/open5gs/
kubectl apply -k ./mongodb/ -n open5gs

kubectl wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=mongodb -n open5gs --timeout=600s
```

---

### E06 — `cannot import name 'SON' from 'bson'`

**Symptom:**
```
ImportError: cannot import name 'SON' from 'bson'
```

**Cause:** The standalone `bson` package was installed alongside `pymongo`. They conflict. The `SON` class is part of pymongo's internal bson only.

**Solution:**
```bash
source ../venv/bin/activate
pip uninstall bson -y
pip install "pymongo==4.6.3"
python3 ./modify-subscribers.py add
deactivate
```

**Rule:** Never run `pip install bson pymongo`. Only install `pymongo`.

---

### E07 — `No module named 'bson.objectid'`

**Symptom:**
```
ModuleNotFoundError: No module named 'bson.objectid'
```

**Cause:** Same root cause as E06. The standalone `bson` package may also exist at the system level and leak into the venv.

**Solution:**
```bash
source ../venv/bin/activate

pip uninstall bson pymongo -y
pip3 show bson 2>/dev/null && sudo pip3 uninstall bson -y || true
sudo apt-get remove -y python3-bson 2>/dev/null || true

pip install "pymongo==4.6.3"
python3 -c "from bson.objectid import ObjectId; print('OK')"

python3 ./modify-subscribers.py add
deactivate
```

---

### E08 — `required file not found for ./venv/bin/pip`

**Symptom:** pip fails to run after activating the virtual environment.

**Cause:** The venv was created with a broken Python installation.

**Solution:**
```bash
deactivate 2>/dev/null || true
sudo apt-get install --reinstall -y python3-pip python3-venv

rm -rf ../venv
python3 -m venv ../venv
source ../venv/bin/activate
pip --version
pip install "pymongo==4.6.3"
```

---

### E09 — `python3: command not found`

**Symptom:** Python3 is not available on a fresh VM.

**Cause:** Minimal Ubuntu 24.04 server images do not include Python3.

**Solution:**
```bash
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv
```

---

### E10 — GNU Radio: `can't open file './multi_ue_scenario.py'`

**Symptom:**
```
python3: can't open file './multi_ue_scenario.py': No such file or directory
```

**Cause:** `start_gnu.sh` uses the relative path `./multi_ue_scenario.py`. Running it from any directory other than `/srsran/config` fails.

**Solution:** Always `cd` to `/srsran/config` first:
```bash
k8s-shell.sh ue1 open5gs
cd /srsran/config
./start_gnu.sh 1
```

---

### E11 — GNU Radio: `vmcircbuf_createfilemapping: createfilemapping is not available`

**Symptom:**
```
/root/.gnuradio/prefs/vmcircbuf_default_factory: No such file or directory
vmcircbuf_createfilemapping: createfilemapping is not available
```

**Cause:** GNU Radio cannot find its buffer backend configuration. The prefs directory does not exist inside the container.

**Solution:**
```bash
k8s-shell.sh ue1 open5gs
mkdir -p /root/.gnuradio/prefs
echo "mmap_shm_open" > /root/.gnuradio/prefs/vmcircbuf_default_factory
cd /srsran/config
./start_gnu.sh 1
```

This must be done each time after a pod restart — containers do not persist filesystem state.

---

### E12 — UE stuck in `Attaching UE` indefinitely

**Symptom:** UE log shows `Attaching UE...` and never reaches `RRC Connected`.

**Cause:** GNU Radio was started before the gNB and UE were ready. The ZMQ broker connects to ports that are not yet open. The script shows `Press Enter to quit` even with no I/Q flowing — there is no error message.

**Solution:** Strictly follow the startup order: gNB → UE → GNU Radio.

To recover:
```bash
# Press Enter in the GNU Radio terminal to kill the broker
# Press Ctrl+C in the UE terminal
# Press Ctrl+C in the gNB terminal

k8s-shell.sh ue1 open5gs
rm -f /dev/shm/gr-*

# Restart in strict order
```

---

### E13 — Grafana credentials fail

**Symptom:** `admin:prom-operator` does not work on the Grafana login page.

**Cause:** The Helm values file overrides the default credentials.

**Solution:**
```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode; echo
```

---

### E14 — `add_route.sh` prints namespace errors

**Symptom:**
```
Cannot open network namespace "ue2": No such file or directory
Error: Nexthop has invalid gateway.
```

**Cause:** The script loops over all 10 possible UEs. UEs 2–10 don't exist. The gateway error is because `srsue` already installed the correct route automatically.

**This is not an error.** Verify the route:
```bash
ip netns exec ue1 ip route
# Must show: default via 10.41.0.1 dev tun_srsue
```

---

### E15 — UPF shows DL/UL traffic with 0 UEs

**Symptom:** Grafana shows non-zero UPF throughput even when no UE is attached.

**Cause:** Normal. The container network metric captures all interface traffic including PFCP heartbeat messages between SMF and UPF every ~10 seconds, plus Kubernetes DNS and health probes. This is the idle baseline.

**No action needed.** Subtract this baseline value when measuring user-plane throughput in experiments.

---

### E16 — containerd incompatible with Kubernetes 1.30

**Symptom:** Pods fail to start after kubeadm init. Kubelet cannot connect to containerd.

**Cause:** The Ubuntu default `containerd` package is outdated.

**Solution:** Remove it and install from Docker's repo as shown in Step 1:
```bash
sudo systemctl stop containerd
sudo apt-get remove -y containerd
sudo rm -rf /etc/containerd /var/lib/containerd /run/containerd
# Then follow Step 1 completely
```

---

## Architecture Overview

```
┌───────────────────── 5g-lab — Ubuntu 24.04 ──────────────────────┐
│                                                                    │
│  ┌──── namespace: open5gs ────────────────────┐  ┌── monitoring ─┐│
│  │                                            │  │  Prometheus   ││
│  │  ┌── 5G Core ───────────────────────────┐  │  │  Grafana:32000││
│  │  │  MongoDB      (subscriber store)     │  │  └───────────────┘│
│  │  │  NRF · SCP · AUSF · UDM · UDR · PCF │  │                   │
│  │  │  AMF   N2: 10.10.3.200  NGAP/SCTP   │  │                   │
│  │  │  SMF1 ──N4──► UPF1   N3: 10.10.3.1  │  │                   │
│  │  │  SMF2 ──N4──► UPF2   N3: 10.10.3.2  │  │                   │
│  │  └──────────────────────────────────────┘  │                   │
│  │                                            │                   │
│  │  ┌── RAN ───────────────────────────────┐  │                   │
│  │  │  srsRAN gNB    pci=1, bw=10MHz, ZMQ  │  │                   │
│  │  │       ↕ ZMQ I/Q samples              │  │                   │
│  │  │  GNU Radio broker                    │  │                   │
│  │  │       (run from /srsran/config)      │  │                   │
│  │  │       ↕ ZMQ I/Q samples              │  │                   │
│  │  │  srsRAN UE1   tun_srsue: 10.41.0.x  │  │                   │
│  │  │  iperf2-server  N3: 10.10.3.233      │  │                   │
│  │  └──────────────────────────────────────┘  │                   │
│  └────────────────────────────────────────────┘                   │
│                                                                    │
│  ┌── OVS Bridges (host kernel) ──────────────────────────────┐    │
│  │    n2br (N2 / NGAP)   n3br (N3 / GTP-U)   n4br (N4 / PFCP)│   │
│  └───────────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────┘
```

**Mandatory startup order on every boot:**

```
[Terminal 1] k8s-shell.sh gnb open5gs → /srsran/config/start_gnb.sh
             Wait for: NG Setup Response

[Terminal 2] k8s-shell.sh ue1 open5gs → /srsran/config/start_ue.sh 1
             Wait for: PDU Session Establishment successful

[Terminal 3] k8s-shell.sh ue1 open5gs → cd /srsran/config → ./start_gnu.sh 1
             Wait for: Press Enter to quit  ← do NOT press Enter

[Terminal 4] k8s-shell.sh ue1 open5gs → /srsran/config/add_route.sh
             Test:     ip netns exec ue1 ping -c 4 8.8.8.8
```

---

*Based on [sulaimanalmani/k8s_srsran_open5gs](https://github.com/sulaimanalmani/k8s_srsran_open5gs) and [niloysh/open5gs-k8s](https://github.com/niloysh/open5gs-k8s)*


---

## 18. AI Assistant Dashboard Deployment

The Dashboard is a minimalist, Nokia-themed conversational UI powered by Google's Gemini 2.5 Flash model. It connects to your Kubernetes cluster and Prometheus metrics server to provide real-time, interactive management of your 5G lab.

### Prerequisites & Requirements
- **OS**: Linux VM (Ubuntu/Debian recommended)
- **Kubernetes Access**: The backend requires `kubectl` to be installed and configured with access to the `open5gs` namespace.
- **Python**: Python 3.10+ (Python 3.12 was used in this lab).
- **Network**: The backend must have access to the Prometheus server (default: `http://10.100.125.233:9090`).
- **Google Gemini API Key**: Required for the LLM function calling.

### Setup Instructions

1. **Clone the repository:**
   ```bash
   git clone https://github.com/mezlin/5G-Lab.git
   cd 5G-Lab/dashboard
   ```

2. **Configure the Backend:**
   Navigate to the backend directory and set up a Python virtual environment:
   ```bash
   cd backend
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

3. **Set up Environment Variables:**
   Create a `.env` file in the `dashboard/backend` directory:
   ```bash
   echo "GEMINI_API_KEY=your_google_gemini_api_key_here" > .env
   ```

4. **Start the Backend API:**
   Ensure your virtual environment is active, then run the Flask server:
   ```bash
   nohup python app.py > backend.log 2>&1 &
   ```
   *The backend will start on `http://0.0.0.0:5001`.*

5. **Start the Frontend UI:**
   Navigate to the frontend directory and start a simple HTTP server:
   ```bash
   cd ../frontend
   python3 -m http.server 3000
   ```

6. **Access the Dashboard:**
   Open your browser and navigate to `http://<VM_IP>:3000`. You can now chat with the AI about your network state!

### Security Note
The AI is configured to securely propose bash/kubectl commands rather than executing them directly. All state-modifying actions require explicit user confirmation via the UI.
