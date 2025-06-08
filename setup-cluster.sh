#!/bin/bash

# Kubernetes Cluster Setup Script for EAS Self-Hosting
# This script helps initialize a new cluster or join existing ones

set -e

function show_help() {
    echo "Usage: $0 [OPTION]"
    echo "Setup Kubernetes cluster for EAS self-hosting"
    echo ""
    echo "Options:"
    echo "  init        Initialize a new cluster (master node)"
    echo "  join        Get join command for worker nodes"
    echo "  status      Show cluster status"
    echo "  install     Install required tools (kubectl, kubeadm, etc.)"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 init                    # Initialize master node"
    echo "  $0 join                    # Get worker join command"
    echo "  $0 install                 # Install Kubernetes tools"
}

function install_tools() {
    echo "🔧 Installing Kubernetes tools..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        echo "📱 Detected macOS - installing via Homebrew"
        if ! command -v brew &> /dev/null; then
            echo "❌ Homebrew not found. Please install Homebrew first."
            exit 1
        fi
        
        brew install kubectl
        echo "✅ kubectl installed"
        
        # For local development, suggest Docker Desktop or Minikube
        echo "🐳 For local development, consider installing:"
        echo "   - Docker Desktop (includes Kubernetes): brew install --cask docker"
        echo "   - Minikube: brew install minikube"
        echo "   - Kind: brew install kind"
        
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        echo "🐧 Detected Linux - installing kubectl, kubeadm, kubelet"
        
        # Add Kubernetes apt repository
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl
        curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
        echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
        
        sudo apt-get update
        sudo apt-get install -y kubelet kubeadm kubectl
        sudo apt-mark hold kubelet kubeadm kubectl
        
        echo "✅ Kubernetes tools installed"
        
        # Install Docker if not present
        if ! command -v docker &> /dev/null; then
            echo "🐳 Installing Docker..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker $USER
            echo "✅ Docker installed. Please log out and back in for group changes to take effect."
        fi
    fi
}

function init_cluster() {
    echo "🚀 Initializing Kubernetes cluster..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "📱 For macOS, please use one of these local solutions:"
        echo "   1. Docker Desktop with Kubernetes enabled"
        echo "   2. Minikube: minikube start --driver=docker"
        echo "   3. Kind: kind create cluster --name eas-cluster"
        return 0
    fi
    
    # Linux cluster initialization
    echo "🔧 Disabling swap (required for Kubernetes)..."
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    echo "🚀 Initializing cluster with kubeadm..."
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16
    
    echo "⚙️ Setting up kubeconfig..."
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    
    echo "🌐 Installing Flannel CNI..."
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
    
    echo "✅ Cluster initialized successfully!"
    echo ""
    echo "📋 To join worker nodes, run the following command on each worker:"
    sudo kubeadm token create --print-join-command
    
    echo ""
    echo "🔍 Cluster status:"
    kubectl get nodes
}

function get_join_command() {
    echo "📋 Current join command for worker nodes:"
    if command -v kubeadm &> /dev/null; then
        sudo kubeadm token create --print-join-command
    else
        echo "❌ kubeadm not found. This command should be run on the master node."
        exit 1
    fi
}

function show_status() {
    echo "📊 Kubernetes Cluster Status:"
    echo ""
    
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl not found. Please install it first."
        exit 1
    fi
    
    echo "🔗 Cluster Info:"
    kubectl cluster-info
    echo ""
    
    echo "📦 Nodes:"
    kubectl get nodes -o wide
    echo ""
    
    echo "🏠 Namespaces:"
    kubectl get namespaces
    echo ""
    
    if kubectl get namespace eas-self-hosting &> /dev/null; then
        echo "🚀 EAS Self-Hosting Status:"
        kubectl get pods -n eas-self-hosting
        echo ""
        kubectl get services -n eas-self-hosting
    else
        echo "ℹ️ EAS Self-Hosting not yet deployed"
    fi
}

# Main script logic
case "${1:-help}" in
    "init")
        init_cluster
        ;;
    "join")
        get_join_command
        ;;
    "status")
        show_status
        ;;
    "install")
        install_tools
        ;;
    "help")
        show_help
        ;;
    *)
        echo "❌ Unknown option: $1"
        show_help
        exit 1
        ;;
esac

