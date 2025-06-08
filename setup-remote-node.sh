#!/bin/bash

# Kubernetes Remote Node Setup Script
# This script will configure a Linux machine to join a Kubernetes cluster

set -e

echo "🚀 Setting up Kubernetes on remote node..."

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo "❌ This script should not be run as root. Please run as a regular user with sudo access."
        exit 1
    fi
}

# Function to install Docker
install_docker() {
    echo "🐳 Installing Docker..."
    
    # Remove old Docker versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Update package index
    sudo apt-get update
    
    # Install packages to allow apt to use a repository over HTTPS
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Set up the stable repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Enable and start Docker
    sudo systemctl enable docker
    sudo systemctl start docker
    
    echo "✅ Docker installed successfully"
}

# Function to install Kubernetes tools
install_kubernetes() {
    echo "☸️ Installing Kubernetes tools..."
    
    # Update the apt package index and install packages needed to use the Kubernetes apt repository
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl
    
    # Download the Google Cloud public signing key
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
    
    # Add the Kubernetes apt repository
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    
    # Update apt package index, install kubelet, kubeadm and kubectl
    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    
    # Mark them as held back from automatic updates
    sudo apt-mark hold kubelet kubeadm kubectl
    
    echo "✅ Kubernetes tools installed successfully"
}

# Function to configure system for Kubernetes
configure_system() {
    echo "⚙️ Configuring system for Kubernetes..."
    
    # Disable swap
    echo "📴 Disabling swap..."
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    # Load required kernel modules
    echo "🔧 Configuring kernel modules..."
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
    echo "📦 Configuring containerd..."
    sudo mkdir -p /etc/containerd
    containerd config default | sudo tee /etc/containerd/config.toml
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    sudo systemctl restart containerd
    
    echo "✅ System configured successfully"
}

# Function to initialize master node
init_master() {
    echo "🎯 Initializing Kubernetes master node..."
    
    # Initialize the cluster
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$(hostname -I | awk '{print $1}')
    
    # Set up kubeconfig for the user
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    
    # Install Flannel CNI
    echo "🌐 Installing Flannel CNI..."
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
    
    # Wait for master node to be ready
    echo "⏳ Waiting for master node to be ready..."
    kubectl wait --for=condition=Ready node --timeout=300s --all
    
    echo "✅ Master node initialized successfully"
    echo ""
    echo "📋 To join worker nodes, run the following command on each worker:"
    sudo kubeadm token create --print-join-command
}

# Function to join as worker node
join_worker() {
    local join_command="$1"
    
    if [ -z "$join_command" ]; then
        echo "❌ Join command not provided"
        echo "Usage: $0 worker 'kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>'"
        exit 1
    fi
    
    echo "👷 Joining as worker node..."
    echo "Command: $join_command"
    
    # Execute the join command
    sudo $join_command
    
    echo "✅ Successfully joined the cluster as worker node"
}

# Function to show cluster status
show_status() {
    echo "📊 Cluster Status:"
    echo ""
    
    if command -v kubectl &> /dev/null; then
        echo "🔗 Cluster Info:"
        kubectl cluster-info 2>/dev/null || echo "❌ Not connected to cluster"
        echo ""
        
        echo "📦 Nodes:"
        kubectl get nodes -o wide 2>/dev/null || echo "❌ Cannot access nodes"
        echo ""
        
        echo "🏠 Pods:"
        kubectl get pods --all-namespaces 2>/dev/null || echo "❌ Cannot access pods"
    else
        echo "❌ kubectl not installed"
    fi
}

# Main script logic
case "${1:-help}" in
    "install")
        check_root
        install_docker
        install_kubernetes
        configure_system
        echo "🎉 Installation complete! System is ready for Kubernetes."
        echo "📝 Next steps:"
        echo "   - To initialize as master: $0 master"
        echo "   - To join as worker: $0 worker '<join-command>'"
        ;;
    "master")
        check_root
        init_master
        ;;
    "worker")
        check_root
        join_worker "$2"
        ;;
    "status")
        show_status
        ;;
    "help")
        echo "Usage: $0 [OPTION]"
        echo "Setup and manage Kubernetes cluster"
        echo ""
        echo "Options:"
        echo "  install     Install Docker and Kubernetes tools"
        echo "  master      Initialize as master node"
        echo "  worker      Join as worker node (requires join command)"
        echo "  status      Show cluster status"
        echo "  help        Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 install                                    # Install required tools"
        echo "  $0 master                                     # Initialize master node"
        echo "  $0 worker 'kubeadm join ...'                 # Join as worker"
        echo "  $0 status                                     # Show cluster status"
        ;;
    *)
        echo "❌ Unknown option: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac

