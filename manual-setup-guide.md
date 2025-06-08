# Manual Kubernetes Setup Guide for 192.168.29.35

Since SSH connection is not working, follow these steps directly on the Linux machine (sonukumar@192.168.29.35):

## Step 1: Prepare the System

```bash
# Update the system
sudo apt-get update && sudo apt-get upgrade -y

# Install essential tools
sudo apt-get install -y curl wget apt-transport-https ca-certificates gnupg lsb-release
```

## Step 2: Install Docker

```bash
# Remove old Docker versions
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Add user to docker group
sudo usermod -aG docker $USER

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Test Docker installation
sudo docker run hello-world
```

## Step 3: Install Kubernetes Tools

```bash
# Download the Google Cloud public signing key
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg

# Add the Kubernetes apt repository
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update apt package index and install kubelet, kubeadm and kubectl
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

# Mark them as held back from automatic updates
sudo apt-mark hold kubelet kubeadm kubectl
```

## Step 4: Configure System for Kubernetes

```bash
# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo modprobe br_netfilter
sudo sysctl --system

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

## Step 5: Initialize Kubernetes Master Node

```bash
# Get the machine's IP address
ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1

# Initialize the cluster (replace <YOUR-IP> with the actual IP)
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.29.35

# Set up kubeconfig for the user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Flannel CNI network plugin
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Wait for master node to be ready
kubectl get nodes -w
```

## Step 6: Get Join Command for Worker Nodes

```bash
# Generate a new join command (save this output)
sudo kubeadm token create --print-join-command
```

## Step 7: Verify Cluster Status

```bash
# Check cluster info
kubectl cluster-info

# Check nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods --all-namespaces
```

## Step 8: Copy Kubeconfig to Windows Machine

On the Linux machine, display the kubeconfig content:

```bash
cat ~/.kube/config
```

Copy this content and save it to a file on your Windows machine, then update the server address to use the Linux machine's IP.

## Troubleshooting

If you encounter issues:

1. **Check Docker status:**
   ```bash
   sudo systemctl status docker
   ```

2. **Check kubelet logs:**
   ```bash
   sudo journalctl -xeu kubelet
   ```

3. **Reset cluster if needed:**
   ```bash
   sudo kubeadm reset
   sudo rm -rf ~/.kube
   ```

4. **Check firewall:**
   ```bash
   sudo ufw status
   # If enabled, you may need to allow Kubernetes ports
   sudo ufw allow 6443/tcp
   sudo ufw allow 2379:2380/tcp
   sudo ufw allow 10250/tcp
   sudo ufw allow 10251/tcp
   sudo ufw allow 10252/tcp
   ```

## After Master Setup

1. Copy the join command output from Step 6
2. Save the kubeconfig from Step 8 to your Windows machine
3. You can then use this cluster to deploy the EAS workloads

## SSH Connection Issues

To fix SSH connectivity for future remote management:

```bash
# Check SSH service status
sudo systemctl status ssh

# Enable SSH if not running
sudo systemctl enable ssh
sudo systemctl start ssh

# Check SSH configuration
sudo nano /etc/ssh/sshd_config
# Ensure PasswordAuthentication yes (if using passwords)
# Ensure PubkeyAuthentication yes (if using keys)

# Restart SSH service
sudo systemctl restart ssh

# Check if firewall is blocking SSH
sudo ufw allow ssh
```

