# Quick Start Guide

This is a condensed guide to get your e-commerce application running on Kubernetes quickly.

## Prerequisites Checklist

- [ ] Kubernetes cluster running (v1.24+)
- [ ] kubectl installed and configured
- [ ] Docker images built and pushed to registry
- [ ] Domain name ready (for production)
- [ ] Cloudflare API token (if using Cloudflare DNS)

## Quick Deploy (5 Steps)

### 1. Update Secrets

Edit `01-secrets.yaml` with your actual credentials:

```bash
# Generate base64 values
echo -n 'mypassword' | base64
echo -n 'myuser' | base64
echo -n 'mydb' | base64
```

Update the file with these base64 values and your Cloudflare API token.

### 2. Update Configuration

Replace `2jz.space` with your domain in:
- `08-traefik-config.yaml` (email field)
- `09-ingress.yaml` (domain fields)

Update image reference in `06-app.yaml`:
- Change `ghcr.io/your-github-username/your-repo-app:latest` to your actual image

### 3. Install Traefik CRDs

```bash
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.2/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
```

### 4. Deploy

Use the automated script:

```bash
./deploy.sh
```

Or deploy manually:

```bash
kubectl apply -f .
```

### 5. Configure DNS

Get the LoadBalancer IP:

```bash
kubectl get svc traefik -n ecommerce
```

Point your domain's A record to this IP address.

## Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n ecommerce

# Check services
kubectl get svc -n ecommerce

# View logs
kubectl logs -n ecommerce -l app=traefik -f

# Test locally (while DNS propagates)
curl -H "Host: 2jz.space" http://<LOADBALANCER_IP>
```

## Access Your Application

- **Production**: https://2jz.space (or your domain)
- **Health Check**: https://2jz.space/health
- **API**: https://2jz.space/products

## Common Commands

```bash
# View all resources
kubectl get all -n ecommerce

# Scale the app
kubectl scale deployment app -n ecommerce --replicas=3

# View logs
kubectl logs -n ecommerce -l app=flask-app
kubectl logs -n ecommerce -l app=traefik

# Describe a pod
kubectl describe pod -n ecommerce <pod-name>

# Execute command in pod
kubectl exec -it -n ecommerce <pod-name> -- /bin/bash

# Port forward (for local testing)
kubectl port-forward -n ecommerce svc/nginx 8080:80

# Restart a deployment
kubectl rollout restart deployment app -n ecommerce

# View certificate status (in Traefik logs)
kubectl logs -n ecommerce -l app=traefik | grep -i acme
```

## Troubleshooting Quick Fixes

### Pods not starting
```bash
kubectl describe pod -n ecommerce <pod-name>
kubectl logs -n ecommerce <pod-name>
```

### Database connection issues
```bash
kubectl exec -n ecommerce <postgres-pod> -- pg_isready
kubectl logs -n ecommerce -l app=postgres
```

### Certificate not issued
```bash
# Check Traefik logs
kubectl logs -n ecommerce -l app=traefik | grep -i acme

# Verify Cloudflare token
kubectl get secret cloudflare-credentials -n ecommerce -o yaml

# Check DNS
dig 2jz.space
```

### LoadBalancer pending (local cluster)

**Minikube:**
```bash
minikube tunnel
```

**kind:**
```bash
kubectl port-forward -n ecommerce svc/traefik 8080:80 8443:443
# Access via http://localhost:8080
```

## Uninstall

```bash
./uninstall.sh
```

Or manually:

```bash
kubectl delete namespace ecommerce
```

## Next Steps

- Set up monitoring (Prometheus/Grafana)
- Configure Horizontal Pod Autoscaling
- Implement backup strategy for PostgreSQL
- Set up CI/CD pipeline
- Configure NetworkPolicies for security
- Add pod disruption budgets

## Support

For detailed instructions, see [README.md](README.md)

## File Structure

```
.
├── 00-namespace.yaml           # Namespace definition
├── 01-secrets.yaml             # Secrets ✅ CONFIGURED
├── 02-configmaps.yaml          # Application configs
├── 03-pvcs.yaml                # Persistent storage
├── 04-postgres.yaml            # PostgreSQL database
├── 05-redis.yaml               # Redis cache
├── 06-app.yaml                 # Flask application ⚠️ UPDATE IMAGE
├── 07-nginx.yaml               # Nginx reverse proxy
├── 08-traefik-config.yaml      # Traefik ingress controller ✅ CONFIGURED
├── 09-ingress.yaml             # Ingress routes ✅ CONFIGURED
├── deploy.sh                   # Deployment script
├── uninstall.sh                # Cleanup script
├── README.md                   # Detailed documentation
├── QUICKSTART.md              # This file
├── MIGRATION.md                # Docker→K8s migration guide
└── docker/                     # Original Docker Compose (reference)
```
