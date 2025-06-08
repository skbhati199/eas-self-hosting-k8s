#!/bin/bash

# EAS Self-Hosting Kubernetes Deployment Script

set -e

echo "🚀 Deploying EAS Self-Hosting to Kubernetes..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

echo "✅ Kubernetes cluster is accessible"

# Apply manifests in order
echo "📦 Creating namespace and secrets..."
kubectl apply -f k8s/namespace.yaml

echo "📦 Deploying PostgreSQL..."
kubectl apply -f k8s/postgres.yaml

echo "📦 Deploying Redis..."
kubectl apply -f k8s/redis.yaml

echo "⏳ Waiting for database services to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n eas-self-hosting --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n eas-self-hosting --timeout=300s

echo "📦 Deploying EAS Server and Workers..."
kubectl apply -f k8s/eas-server.yaml

echo "⏳ Waiting for EAS services to be ready..."
kubectl wait --for=condition=ready pod -l app=eas-server -n eas-self-hosting --timeout=300s

echo "✅ Deployment complete!"
echo ""
echo "📊 Checking deployment status:"
kubectl get pods -n eas-self-hosting
echo ""
echo "🌐 Getting service information:"
kubectl get services -n eas-self-hosting
echo ""
echo "🔗 To access EAS server:"
echo "   kubectl port-forward service/eas-server 3000:3000 -n eas-self-hosting"
echo "   Then visit: http://localhost:3000"
echo ""
echo "📝 To view logs:"
echo "   kubectl logs -l app=eas-server -n eas-self-hosting -f"
echo "   kubectl logs -l app=eas-worker -n eas-self-hosting -f"

