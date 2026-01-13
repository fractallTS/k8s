#!/bin/bash
# Uninstall script for e-commerce Kubernetes application

set -e

echo "========================================"
echo "E-commerce K8s Uninstall Script"
echo "========================================"
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

# Confirm deletion
echo -e "${RED}WARNING: This will delete all resources in the 'ecommerce' namespace.${NC}"
echo -e "${RED}All data in PersistentVolumes will be lost!${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_info "Uninstall cancelled."
    exit 0
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed."
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace ecommerce &> /dev/null; then
    print_warn "Namespace 'ecommerce' does not exist. Nothing to uninstall."
    exit 0
fi

print_info "Deleting namespace 'ecommerce' and all resources..."
kubectl delete namespace ecommerce

print_info "Waiting for namespace deletion to complete..."
kubectl wait --for=delete namespace/ecommerce --timeout=120s || print_warn "Namespace deletion timed out"

# Check if PVs were created and still exist
print_info "Checking for orphaned PersistentVolumes..."
PVS=$(kubectl get pv -o json | jq -r '.items[] | select(.spec.claimRef.namespace=="ecommerce") | .metadata.name' 2>/dev/null || echo "")

if [ -n "$PVS" ]; then
    print_warn "Found orphaned PersistentVolumes:"
    echo "$PVS"
    echo ""
    read -p "Do you want to delete these PersistentVolumes? (yes/no): " -r
    echo ""
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        for pv in $PVS; do
            print_info "Deleting PV: $pv"
            kubectl delete pv "$pv"
        done
    else
        print_info "PersistentVolumes not deleted. You may need to clean them up manually."
    fi
else
    print_info "No orphaned PersistentVolumes found."
fi

echo ""
print_info "Uninstall complete!"
print_info "All resources in the 'ecommerce' namespace have been removed."

# Optional: Ask if user wants to remove Traefik CRDs
echo ""
read -p "Do you want to remove Traefik CRDs? (yes/no): " -r
echo ""

if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_info "Removing Traefik CRDs..."
    kubectl delete crd ingressroutes.traefik.io || print_warn "Failed to delete ingressroutes CRD"
    kubectl delete crd ingressroutetcps.traefik.io || print_warn "Failed to delete ingressroutetcps CRD"
    kubectl delete crd ingressrouteudps.traefik.io || print_warn "Failed to delete ingressrouteudps CRD"
    kubectl delete crd middlewares.traefik.io || print_warn "Failed to delete middlewares CRD"
    kubectl delete crd middlewaretcps.traefik.io || print_warn "Failed to delete middlewaretcps CRD"
    kubectl delete crd tlsoptions.traefik.io || print_warn "Failed to delete tlsoptions CRD"
    kubectl delete crd tlsstores.traefik.io || print_warn "Failed to delete tlsstores CRD"
    kubectl delete crd traefikservices.traefik.io || print_warn "Failed to delete traefikservices CRD"
    kubectl delete crd serverstransports.traefik.io || print_warn "Failed to delete serverstransports CRD"
    kubectl delete clusterrole traefik-role || print_warn "Failed to delete ClusterRole"
    kubectl delete clusterrolebinding traefik-role-binding || print_warn "Failed to delete ClusterRoleBinding"
    print_info "Traefik CRDs removed."
else
    print_info "Traefik CRDs not removed."
fi

echo ""
print_info "Uninstall script finished!"
