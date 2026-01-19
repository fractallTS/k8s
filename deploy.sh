#!/bin/bash
# Deployment script for e-commerce Kubernetes application

set -e

echo "=================================="
echo "E-commerce K8s Deployment Script"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

print_info "kubectl is installed"

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_info "Connected to Kubernetes cluster"

# Check if Traefik CRDs are installed
print_info "Checking for Traefik CRDs..."
if ! kubectl get crd ingressroutes.traefik.io &> /dev/null; then
    print_warn "Traefik CRDs not found. Installing..."
    kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.2/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
    print_info "Traefik CRDs installed"
else
    print_info "Traefik CRDs already installed"
fi

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Deploy in order
print_info "Creating namespace..."
kubectl apply -f "$SCRIPT_DIR/00-namespace.yaml"

print_info "Creating secrets..."
kubectl apply -f "$SCRIPT_DIR/01-secrets.yaml"

print_info "Creating ConfigMaps..."
kubectl apply -f "$SCRIPT_DIR/02-configmaps.yaml"

print_info "Creating PersistentVolumeClaims..."
kubectl apply -f "$SCRIPT_DIR/03-pvcs.yaml"

print_info "Deploying PostgreSQL..."
kubectl apply -f "$SCRIPT_DIR/04-postgres.yaml"

print_info "Deploying Redis..."
kubectl apply -f "$SCRIPT_DIR/05-redis.yaml"

print_info "Deploying Flask application..."
kubectl apply -f "$SCRIPT_DIR/06-app.yaml"

print_info "Deploying Nginx..."
kubectl apply -f "$SCRIPT_DIR/07-nginx.yaml"

print_info "Deploying Traefik..."
kubectl apply -f "$SCRIPT_DIR/08-traefik-config.yaml"

print_info "Creating Ingress routes..."
kubectl apply -f "$SCRIPT_DIR/09-ingress.yaml"

echo ""
print_info "Deployment complete!"
echo ""

# Wait for pods to be ready
print_info "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n ecommerce --timeout=120s || print_warn "PostgreSQL pod not ready yet"
kubectl wait --for=condition=ready pod -l app=redis -n ecommerce --timeout=120s || print_warn "Redis pod not ready yet"
kubectl wait --for=condition=ready pod -l app=flask-app -n ecommerce --timeout=120s || print_warn "App pod not ready yet"
kubectl wait --for=condition=ready pod -l app=nginx -n ecommerce --timeout=120s || print_warn "Nginx pod not ready yet"
kubectl wait --for=condition=ready pod -l app=traefik -n ecommerce --timeout=120s || print_warn "Traefik pod not ready yet"

echo ""
print_info "Pod status:"
kubectl get pods -n ecommerce

echo ""
print_info "Services:"
kubectl get svc -n ecommerce

echo ""
print_info "Getting Traefik LoadBalancer IP..."
EXTERNAL_IP=$(kubectl get svc traefik -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [ -z "$EXTERNAL_IP" ]; then
    EXTERNAL_IP=$(kubectl get svc traefik -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
fi

if [ "$EXTERNAL_IP" = "pending" ] || [ -z "$EXTERNAL_IP" ]; then
    print_warn "LoadBalancer IP is pending. This is normal for local clusters."
    print_warn "For Minikube, run: minikube tunnel"
    print_warn "For kind, use port-forward: kubectl port-forward -n ecommerce svc/traefik 8080:80 8443:443"
else
    print_info "LoadBalancer IP/Hostname: $EXTERNAL_IP"
    print_info "Point your domain DNS A record to this IP"
fi

echo ""
print_info "To check logs, run:"
echo "  kubectl logs -n ecommerce -l app=flask-app"
echo "  kubectl logs -n ecommerce -l app=traefik"

echo ""
print_info "To check status, run:"
echo "  kubectl get all -n ecommerce"

echo ""
print_info "Once DNS is configured and certificate is issued, access your app at:"
echo "  https://2jz.space (or your configured domain)"

echo ""
print_info "Deployment script finished successfully!"
