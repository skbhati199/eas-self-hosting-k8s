.PHONY: help install init deploy status logs clean scale backup join

# Default target
help:
	@echo "EAS Self-Hosting Kubernetes Management"
	@echo ""
	@echo "Usage:"
	@echo "  make install     Install required tools"
	@echo "  make init        Initialize Kubernetes cluster"
	@echo "  make deploy      Deploy EAS to Kubernetes"
	@echo "  make status      Show cluster and deployment status"
	@echo "  make logs        Show EAS server logs"
	@echo "  make logs-worker Show EAS worker logs"
	@echo "  make scale n=N   Scale workers to N replicas"
	@echo "  make backup      Backup PostgreSQL database"
	@echo "  make clean       Remove EAS deployment"
	@echo "  make join        Get worker join command"
	@echo "  make port-forward Port forward EAS server to localhost:3000"

# Install required tools
install:
	./setup-cluster.sh install

# Initialize cluster
init:
	./setup-cluster.sh init

# Deploy EAS
deploy:
	./deploy.sh

# Show status
status:
	./setup-cluster.sh status

# Show logs
logs:
	kubectl logs -l app=eas-server -n eas-self-hosting -f

logs-worker:
	kubectl logs -l app=eas-worker -n eas-self-hosting -f

logs-db:
	kubectl logs -l app=postgres -n eas-self-hosting -f

# Scale workers
scale:
	@if [ -z "$(n)" ]; then echo "Usage: make scale n=<number>"; exit 1; fi
	kubectl scale deployment eas-worker --replicas=$(n) -n eas-self-hosting

# Backup database
backup:
	kubectl exec -it deployment/postgres -n eas-self-hosting -- pg_dump -U eas_user eas_db > backup-$(shell date +%Y%m%d-%H%M%S).sql
	@echo "Database backup created: backup-$(shell date +%Y%m%d-%H%M%S).sql"

# Clean deployment
clean:
	@echo "Removing EAS deployment..."
	kubectl delete namespace eas-self-hosting --ignore-not-found=true
	@echo "EAS deployment removed"

# Get join command
join:
	./setup-cluster.sh join

# Port forward EAS server
port-forward:
	@echo "Port forwarding EAS server to localhost:3000"
	@echo "Visit: http://localhost:3000"
	kubectl port-forward service/eas-server 3000:3000 -n eas-self-hosting

# Check nodes
nodes:
	kubectl get nodes -o wide

# Check pods
pods:
	kubectl get pods -n eas-self-hosting -o wide

# Check services
services:
	kubectl get services -n eas-self-hosting

# Update deployment
update:
	kubectl set image deployment/eas-server eas-server=expo/eas-server:latest -n eas-self-hosting
	kubectl set image deployment/eas-worker eas-worker=expo/eas-server:latest -n eas-self-hosting
	kubectl rollout status deployment/eas-server -n eas-self-hosting
	kubectl rollout status deployment/eas-worker -n eas-self-hosting

