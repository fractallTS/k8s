# Docker to Kubernetes Migration Guide

This document explains the migration from Docker Compose to Kubernetes for the e-commerce application.

## Overview

The Docker Compose application from `../docker/` has been fully migrated to Kubernetes with the following key change:
- **Certificate Management**: Replaced Certbot with Traefik for automatic TLS certificate management

## Architecture Comparison

### Docker Compose Architecture
```
┌─────────────────────────────────────────┐
│  Host Machine (VM)                      │
│  ┌──────────────────────────────────┐  │
│  │  Docker Compose Stack            │  │
│  │                                   │  │
│  │  ┌─────────┐  ┌─────────┐       │  │
│  │  │ Certbot │  │Certbot  │       │  │
│  │  │         │  │ Renew   │       │  │
│  │  └────┬────┘  └─────────┘       │  │
│  │       │ Certs                    │  │
│  │  ┌────▼────┐   ┌──────────┐     │  │
│  │  │  Nginx  │◄──│   App    │     │  │
│  │  │ (TLS)   │   │ (Flask)  │     │  │
│  │  └────┬────┘   └────┬─────┘     │  │
│  │       │             │            │  │
│  │  ┌────▼────┐   ┌────▼─────┐     │  │
│  │  │   DB    │   │  Redis   │     │  │
│  │  │(Postgres│   │          │     │  │
│  │  └─────────┘   └──────────┘     │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
    Ports 80/443 exposed to internet
```

### Kubernetes Architecture
```
┌────────────────────────────────────────────────┐
│  Kubernetes Cluster                            │
│  ┌──────────────────────────────────────────┐ │
│  │  Namespace: ecommerce                    │ │
│  │                                           │ │
│  │  ┌──────────┐                            │ │
│  │  │ Traefik  │ (Ingress + TLS)            │ │
│  │  │  ACME    │                            │ │
│  │  └────┬─────┘                            │ │
│  │       │                                   │ │
│  │  ┌────▼─────┐   ┌───────────┐           │ │
│  │  │  Nginx   │◄──│    App    │           │ │
│  │  │ (×2)     │   │  (Flask)  │           │ │
│  │  │          │   │   (×2)    │           │ │
│  │  └────┬─────┘   └─────┬─────┘           │ │
│  │       │               │                  │ │
│  │  ┌────▼──────┐   ┌────▼──────┐          │ │
│  │  │    DB     │   │   Redis   │          │ │
│  │  │(Postgres) │   │           │          │ │
│  │  │   PVC     │   │    PVC    │          │ │
│  │  └───────────┘   └───────────┘          │ │
│  └──────────────────────────────────────────┘ │
└────────────────────────────────────────────────┘
    LoadBalancer exposes ports 80/443
```

## Component Mapping

| Docker Compose | Kubernetes Equivalent | Notes |
|----------------|----------------------|-------|
| `db` service | `postgres` Deployment + Service | Same PostgreSQL 17 image |
| `redis` service | `redis` Deployment + Service | Same Redis image with AOF persistence |
| `app` service | `app` Deployment + Service | Same Flask app, scaled to 2 replicas |
| `nginx` service | `nginx` Deployment + Service | Same config, scaled to 2 replicas |
| `certbot` + `certbot-renew` | Traefik with ACME | **Major change**: Automatic cert management |
| Docker volumes | PersistentVolumeClaims | Kubernetes-native persistent storage |
| Docker secrets | Kubernetes Secrets | Base64-encoded secrets |
| Environment variables | ConfigMaps + Secrets | Separated config from secrets |
| Docker networks | Kubernetes Services | DNS-based service discovery |
| Port exposure | LoadBalancer Service | Traefik service exposes 80/443 |

## Key Changes

### 1. Certificate Management (Certbot → Traefik)

**Before (Docker Compose):**
- Used Certbot container to obtain certificates
- Required `certbot-renew` container with cron job
- Mounted Docker socket for nginx reload
- Certificates stored in volumes
- Manual DNS challenge setup via Cloudflare plugin

**After (Kubernetes):**
- Traefik handles certificate lifecycle automatically
- Built-in ACME client with DNS-01 challenge
- No separate renewal process needed
- Certificates stored in PVC
- Automatic certificate rotation
- No manual nginx reloads required

**Configuration:**
```yaml
# Traefik ACME configuration
certificatesResolvers:
  cloudflare:
    acme:
      email: admin@2jz.space
      storage: /acme/acme.json
      dnsChallenge:
        provider: cloudflare
        delayBeforeCheck: 30
```

### 2. High Availability

**Docker Compose:**
- Single instance of each service
- No built-in load balancing
- Manual scaling

**Kubernetes:**
- Multiple replicas (app: 2, nginx: 2)
- Automatic load balancing via Services
- Easy scaling: `kubectl scale deployment app --replicas=3`
- Pod disruption budgets possible

### 3. Secrets Management

**Docker Compose:**
```yaml
secrets:
  db_password:
    file: ./secrets/db_password
```

**Kubernetes:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
data:
  db_password: <base64-encoded>
```

### 4. Networking

**Docker Compose:**
- Custom bridge network
- Service discovery via container names
- Direct container-to-container communication

**Kubernetes:**
- Cluster network with Services
- DNS-based service discovery (`app.ecommerce.svc.cluster.local`)
- Service mesh optional (Istio, Linkerd)

### 5. Storage

**Docker Compose:**
```yaml
volumes:
  db_data:
  redis_data:
```

**Kubernetes:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

## What Stayed the Same

1. **Application Code**: No changes to Flask app, database, or Redis
2. **Nginx Configuration**: Same reverse proxy rules
3. **Database Schema**: Same initialization script
4. **HTML Frontend**: Same web interface
5. **Docker Images**: Can use the same images built for Compose
6. **Environment Variables**: Same env vars for app configuration

## Migration Benefits

### Advantages of Kubernetes

1. **Scalability**: Easy horizontal scaling of stateless components
2. **High Availability**: Multiple replicas with automatic failover
3. **Self-Healing**: Automatic pod restarts on failure
4. **Rolling Updates**: Zero-downtime deployments
5. **Resource Management**: CPU/memory limits and requests
6. **Service Discovery**: Built-in DNS for service communication
7. **Health Checks**: Liveness and readiness probes
8. **Declarative Config**: GitOps-friendly YAML manifests
9. **Ecosystem**: Huge ecosystem of tools (Helm, Kustomize, etc.)
10. **Cloud-Native**: Works on any cloud or on-premises

### Traefik Benefits Over Certbot

1. **Automatic**: No manual renewal scripts needed
2. **Integrated**: Ingress and TLS in one component
3. **Dynamic**: Automatically detects new services/routes
4. **Dashboard**: Built-in monitoring dashboard
5. **Load Balancing**: Includes load balancing features
6. **Multiple Providers**: Supports many DNS providers
7. **Middleware**: Request/response modification capabilities
8. **Metrics**: Prometheus metrics built-in

## Migration Effort

### What You Need to Change

1. ✅ **Secrets**: Update `01-secrets.yaml` with your credentials
2. ✅ **Domain**: Replace `2jz.space` with your domain in:
   - `08-traefik-config.yaml` (email)
   - `09-ingress.yaml` (domain)
3. ✅ **Images**: Update image reference in `06-app.yaml`
4. ✅ **DNS**: Point domain A record to LoadBalancer IP

### What's Already Done

- All manifests created and configured
- Traefik ACME setup with Cloudflare DNS-01
- Health checks configured for all services
- Resource limits set for all pods
- RBAC configured for Traefik
- ConfigMaps for all configurations
- PVCs for persistent storage
- Multi-replica deployments for HA

## Deployment Workflow Comparison

### Docker Compose Workflow

```bash
# 1. Clone repo
git clone <repo>

# 2. Create secrets
echo "password" > secrets/db_password

# 3. Deploy
docker compose up -d

# 4. Run certbot manually
docker compose run --rm certbot

# 5. Access
curl https://2jz.space
```

### Kubernetes Workflow

```bash
# 1. Clone repo
git clone <repo>

# 2. Update secrets (base64 encoded)
# Edit 01-secrets.yaml

# 3. Update domain
# Edit 09-ingress.yaml

# 4. Deploy
./deploy.sh

# 5. Configure DNS
# Point A record to LoadBalancer IP

# 6. Access (certificates issued automatically)
curl https://2jz.space
```

## Resource Usage Comparison

| Component | Docker Compose | Kubernetes |
|-----------|----------------|------------|
| PostgreSQL | 1 instance | 1 instance (can scale with replication) |
| Redis | 1 instance | 1 instance (can scale with cluster mode) |
| Flask App | 1 instance | 2 instances (default) |
| Nginx | 1 instance | 2 instances (default) |
| Certbot | 2 containers | 0 (replaced by Traefik) |
| Traefik | 0 | 1 instance |
| **Total Containers** | 5 | 7 pods (better HA) |

## Testing Equivalence

Both deployments provide the same functionality:

```bash
# Health check
curl https://2jz.space/health

# Get products
curl https://2jz.space/products

# Add product
curl -X POST https://2jz.space/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","price":9.99}'

# Update product
curl -X PUT https://2jz.space/products/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated","price":19.99}'

# Delete product
curl -X DELETE https://2jz.space/products/1
```

## Rollback Plan

If you need to rollback to Docker Compose:

```bash
# 1. Backup Kubernetes data
kubectl exec -n ecommerce <postgres-pod> -- pg_dump -U <user> <db> > backup.sql

# 2. Uninstall Kubernetes
./uninstall.sh

# 3. Return to Docker Compose
cd ../docker
docker compose up -d

# 4. Restore data if needed
cat backup.sql | docker exec -i docker-db-1 psql -U <user> <db>
```

## Conclusion

This migration maintains 100% functional equivalence with the Docker Compose setup while gaining:
- Better certificate management (Traefik vs Certbot)
- High availability (multiple replicas)
- Better scalability
- Production-ready architecture
- Cloud-native deployment

The only user-facing change is using Traefik instead of Certbot for certificates, which actually improves the experience with automatic management.
