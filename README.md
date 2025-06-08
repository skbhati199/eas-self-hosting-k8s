# EAS Self-Hosting with Kubernetes

This project provides a complete setup for self-hosting Expo Application Services (EAS) using Kubernetes, with support for multi-node clusters.

## 📦 What's Included

- **EAS Server**: Main API server for handling build requests
- **EAS Workers**: Background workers for processing builds
- **PostgreSQL**: Database for storing build metadata and user data
- **Redis**: Cache and job queue for coordinating work
- **Kubernetes Manifests**: Production-ready K8s configurations
- **Deployment Scripts**: Automated setup and management tools

## 🛠️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   EAS Server    │    │   EAS Workers   │    │   PostgreSQL    │
│   (2 replicas)  │    │   (3 replicas)  │    │   (1 replica)   │
│                 │    │                 │    │                 │
│  Port: 3000     │    │  Background     │    │  Port: 5432     │
│  LoadBalancer   │    │  Processing     │    │  ClusterIP      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                      ┌─────────────────┐
                      │      Redis      │
                      │   (1 replica)   │
                      │                 │
                      │   Port: 6379    │
                      │   ClusterIP     │
                      └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (v1.20+)
- kubectl configured
- At least 4GB RAM and 2 CPU cores available

### 1. Install Required Tools

```bash
# Install kubectl and other Kubernetes tools
./setup-cluster.sh install
```

### 2. Set Up Kubernetes Cluster

#### Option A: Local Development (macOS)

```bash
# Using Docker Desktop
# Enable Kubernetes in Docker Desktop settings

# OR using Minikube
brew install minikube
minikube start --driver=docker --memory=4096 --cpus=2

# OR using Kind
brew install kind
kind create cluster --name eas-cluster
```

#### Option B: Production Cluster (Linux)

```bash
# On the master node
./setup-cluster.sh init

# On worker nodes, run the join command from master output:
# sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

### 3. Configure Secrets

Before deploying, update the secrets in `k8s/namespace.yaml`:

```bash
# Generate base64 encoded values for your secrets
echo -n "your-actual-jwt-secret" | base64
echo -n "your-expo-api-key" | base64
echo -n "your-postgres-password" | base64
```

Update the secrets section in `k8s/namespace.yaml` with your actual values.

### 4. Deploy EAS

```bash
# Deploy all components
./deploy.sh

# Check deployment status
./setup-cluster.sh status
```

### 5. Access EAS Server

```bash
# Port forward to access locally
kubectl port-forward service/eas-server 3000:3000 -n eas-self-hosting

# Visit http://localhost:3000
```

## 🔧 Joining Additional Machines to Cluster

### For Linux Servers

1. **On the master node**, get the join command:
   ```bash
   ./setup-cluster.sh join
   ```

2. **On the new worker machine**:
   ```bash
   # Install Kubernetes tools
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   
   # Add Kubernetes repository
   sudo apt-get update
   sudo apt-get install -y apt-transport-https ca-certificates curl
   curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
   echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
   
   # Install kubelet and kubeadm
   sudo apt-get update
   sudo apt-get install -y kubelet kubeadm
   sudo apt-mark hold kubelet kubeadm
   
   # Disable swap
   sudo swapoff -a
   sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
   
   # Join the cluster (use command from step 1)
   sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
   ```

3. **Verify on master node**:
   ```bash
   kubectl get nodes
   ```

### For macOS/Development Machines

For development, you typically wouldn't join macOS machines to a production cluster. Instead:

1. Set up kubectl to connect to remote cluster:
   ```bash
   # Copy kubeconfig from master node
   scp user@master-node:/home/user/.kube/config ~/.kube/config
   
   # Or manually configure kubectl context
   kubectl config set-cluster eas-cluster --server=https://<master-ip>:6443
   kubectl config set-credentials eas-admin --client-certificate=<cert> --client-key=<key>
   kubectl config set-context eas-context --cluster=eas-cluster --user=eas-admin
   kubectl config use-context eas-context
   ```

## 📊 Monitoring and Management

### View Logs

```bash
# EAS Server logs
kubectl logs -l app=eas-server -n eas-self-hosting -f

# EAS Worker logs
kubectl logs -l app=eas-worker -n eas-self-hosting -f

# Database logs
kubectl logs -l app=postgres -n eas-self-hosting -f
```

### Scale Workers

```bash
# Scale workers based on load
kubectl scale deployment eas-worker --replicas=5 -n eas-self-hosting
```

### Check Resource Usage

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -n eas-self-hosting
```

### Backup Database

```bash
# Create database backup
kubectl exec -it deployment/postgres -n eas-self-hosting -- pg_dump -U eas_user eas_db > backup.sql
```

## 🔐 Security Considerations

1. **Change default passwords**: Update all default passwords in the secrets
2. **Use TLS**: Configure TLS certificates for production
3. **Network policies**: Implement Kubernetes network policies
4. **RBAC**: Set up proper role-based access control
5. **Image scanning**: Scan container images for vulnerabilities

## 🚫 Troubleshooting

### Common Issues

1. **Pods stuck in Pending**:
   ```bash
   kubectl describe pod <pod-name> -n eas-self-hosting
   # Check for resource constraints or node issues
   ```

2. **Database connection issues**:
   ```bash
   kubectl logs -l app=eas-server -n eas-self-hosting
   # Check DATABASE_URL configuration
   ```

3. **Worker not processing jobs**:
   ```bash
   kubectl logs -l app=eas-worker -n eas-self-hosting
   # Check Redis connection and job queue
   ```

### Health Checks

```bash
# Check all components
./setup-cluster.sh status

# Test database connectivity
kubectl exec -it deployment/postgres -n eas-self-hosting -- psql -U eas_user -d eas_db -c "SELECT 1;"

# Test Redis connectivity
kubectl exec -it deployment/redis -n eas-self-hosting -- redis-cli ping
```

## 🔄 Updates and Maintenance

### Update EAS Images

```bash
# Update to latest EAS images
kubectl set image deployment/eas-server eas-server=expo/eas-server:latest -n eas-self-hosting
kubectl set image deployment/eas-worker eas-worker=expo/eas-server:latest -n eas-self-hosting

# Check rollout status
kubectl rollout status deployment/eas-server -n eas-self-hosting
kubectl rollout status deployment/eas-worker -n eas-self-hosting
```

### Cluster Maintenance

```bash
# Drain node for maintenance
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Mark node as schedulable again
kubectl uncordon <node-name>
```

## 📝 Configuration Files

- `docker-compose.yml`: Docker Compose setup for local development
- `k8s/namespace.yaml`: Namespace, secrets, and config maps
- `k8s/postgres.yaml`: PostgreSQL database deployment
- `k8s/redis.yaml`: Redis cache deployment
- `k8s/eas-server.yaml`: EAS server and worker deployments
- `deploy.sh`: Automated deployment script
- `setup-cluster.sh`: Cluster management script

## 🐛 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review Kubernetes and EAS documentation
3. Check logs for specific error messages
4. Ensure all prerequisites are met

## 📜 License

This configuration is provided as-is for educational and development purposes. Please review Expo's licensing terms for EAS usage.

