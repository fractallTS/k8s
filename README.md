# E-commerce Kubernetes Deployment

Production-ready Kubernetes deployment for an e-commerce API stack with PostgreSQL, Redis, Flask, Nginx, and automatic TLS certificate management via Traefik.

## Quick Links

- Quick Start: See [QUICKSTART.md](QUICKSTART.md)
- Migration Guide: See [MIGRATION.md](MIGRATION.md) for Docker→Kubernetes migration details
- **Rolling Update Demo**: See [ROLLING_UPDATE_DEMO.md](ROLLING_UPDATE_DEMO.md) for zero-downtime deployment demonstration
- Deployment Script: Run `./deploy.sh` for automated deployment
- Cleanup Script: Run `./uninstall.sh` to remove everything
- Demo Script: Run `./demo-rolling-update.sh` for automated rolling update test

## Architecture

```
Internet (HTTPS)
      ↓
  Traefik (LoadBalancer)
  - Automatic TLS via Let's Encrypt
  - HTTP→HTTPS redirect
  - DNS-01 challenge (Cloudflare)
      ↓
  Nginx (×2 replicas)
  - Static files
  - Reverse proxy
  - Security headers
      ↓
  Flask App (×2 replicas)
  - REST API
  - Gunicorn server
      ↓
PostgreSQL + Redis
(with persistent storage)
```

### Services

- **PostgreSQL 17** - Database with persistent storage and initialization script
- **Redis** - Cache with AOF persistence
- **Flask App** - Python REST API (2 replicas for HA)
- **Nginx** - Reverse proxy and static file server (2 replicas for HA)
- **Traefik v3.2** - Ingress controller with automatic TLS certificate management

## Key Features

✅ **Automatic TLS** - Let's Encrypt certificates via Traefik with DNS-01 challenge
✅ **High Availability** - Multiple replicas for stateless components
✅ **Self-Healing** - Automatic pod restarts with health checks
✅ **Persistent Storage** - PostgreSQL and Redis data survives pod restarts
✅ **Production-Ready** - Resource limits, security headers, proper RBAC
✅ **Easy Scaling** - Horizontal pod autoscaling ready
✅ **Secrets Management** - Kubernetes native secrets for credentials

## Prerequisites

### Required

1. **Kubernetes Cluster** (v1.24+)
   - Local: Minikube, kind, k3s, or Docker Desktop
   - Cloud: GKE, EKS, AKS, or any managed Kubernetes service

2. **kubectl** installed and configured
   ```bash
   kubectl version --client
   ```

3. **Domain Name** pointing to your cluster's load balancer IP
   - Currently configured for: `2jz.space`
   - Update in [08-traefik-config.yaml](08-traefik-config.yaml) and [09-ingress.yaml](09-ingress.yaml)

4. **Cloudflare API Token** (for DNS-01 challenge)
   - Create at: https://dash.cloudflare.com/profile/api-tokens
   - Required permissions: Zone → DNS → Edit
   - Token scope: Specific zone (your domain)

### Optional

- **Docker** (if building images locally)
- **GitHub Actions** (for automated image builds to GHCR)

## File Structure

```
.
├── 00-namespace.yaml           # Namespace definition
├── 01-secrets.yaml             # Secrets (credentials, API tokens) ✅ CONFIGURED
├── 02-configmaps.yaml          # ConfigMaps (nginx, DB init, HTML)
├── 03-pvcs.yaml                # Persistent Volume Claims
├── 04-postgres.yaml            # PostgreSQL database
├── 05-redis.yaml               # Redis cache
├── 06-app.yaml                 # Flask application (3 replicas, rolling update) ⚠️ UPDATE IMAGE
├── 07-nginx.yaml               # Nginx reverse proxy (3 replicas, rolling update)
├── 08-traefik-config.yaml      # Traefik ingress controller ✅ CONFIGURED
├── 09-ingress.yaml             # Ingress routes and TLS ✅ CONFIGURED
├── deploy.sh                   # Automated deployment script
├── uninstall.sh                # Cleanup script
├── demo-rolling-update.sh      # Rolling update demo script
├── README.md                   # This file (comprehensive guide)
├── QUICKSTART.md               # Quick reference guide
├── MIGRATION.md                # Docker→K8s migration details
├── ROLLING_UPDATE_DEMO.md      # Zero-downtime deployment demonstration
├── .gitignore                  # Git ignore patterns
└── docker/                     # Original Docker Compose setup (reference)
    ├── app/
    │   ├── app.py              # Flask app V1
    │   ├── app-v2.py           # Flask app V2 (for rolling update demo)
    │   └── Dockerfile          # Multi-stage build
    └── .github/workflows/      # CI/CD pipeline
```

## Quick Start

### 1. Update Flask App Image

Edit [06-app.yaml](06-app.yaml) line 25 and replace:
```yaml
image: ghcr.io/REPLACE_GITHUB_OWNER/REPLACE_REPO_NAME-app:latest
```

With your actual image, for example:
```yaml
image: ghcr.io/your-username/your-repo-app:latest
```

**Building the image:**
```bash
cd docker/app
docker build -t ghcr.io/your-username/your-repo-app:latest .
docker push ghcr.io/your-username/your-repo-app:latest
```

### 2. Install Traefik CRDs

```bash
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.2/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
```

### 3. Deploy

Use the automated script:
```bash
./deploy.sh
```

Or deploy manually:
```bash
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-secrets.yaml
kubectl apply -f 02-configmaps.yaml
kubectl apply -f 03-pvcs.yaml
kubectl apply -f 04-postgres.yaml
kubectl apply -f 05-redis.yaml
kubectl apply -f 06-app.yaml
kubectl apply -f 07-nginx.yaml
kubectl apply -f 08-traefik-config.yaml
kubectl apply -f 09-ingress.yaml
```

### 4. Configure DNS

Get the LoadBalancer IP:
```bash
kubectl get svc traefik -n ecommerce
```

Point your domain's A record to this IP:
```
2jz.space  A  <EXTERNAL-IP>
```

### 5. Wait for Certificate

Traefik will automatically request a Let's Encrypt certificate (1-3 minutes).

Monitor progress:
```bash
kubectl logs -n ecommerce -l app=traefik -f
```

### 6. Access Your Application

- **Web Interface**: https://2jz.space
- **API Health**: https://2jz.space/health
- **Products API**: https://2jz.space/products

## Configuration Details

### Secrets (01-secrets.yaml)

Already configured with values from `docker/secrets/`:
- ✅ Database credentials (user, password, name)
- ✅ Cloudflare API token

**Values are base64 encoded from:**
- `docker/secrets/db_user` → ecomuser
- `docker/secrets/db_name` → ecommerce
- `docker/secrets/db_password` → (actual password)
- `docker/secrets/cloudflare.ini` → CyFvVlCwZyr4XDl6ut4R2vmEwB83nGOPgCzuCeqP

### Domain Configuration

Already configured for `2jz.space`:
- ✅ Email: `admin@2jz.space` in [08-traefik-config.yaml](08-traefik-config.yaml)
- ✅ Domain: `2jz.space` in [09-ingress.yaml](09-ingress.yaml)

**To change domain:** Update both files above with your domain.

### Application Image

⚠️ **Action Required:** Update image in [06-app.yaml](06-app.yaml)

Current placeholder:
```yaml
image: ghcr.io/REPLACE_GITHUB_OWNER/REPLACE_REPO_NAME-app:latest
```

### Health Probes Configuration

All services are configured with liveness and readiness probes for high availability and zero-downtime deployments. Here's the rationale behind the chosen values:

#### Flask Application (06-app.yaml)

**Readiness Probe:**
```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 5000
  initialDelaySeconds: 10    # Flask + Gunicorn startup takes ~8-10s
  periodSeconds: 5           # Check frequently to quickly detect issues
  timeoutSeconds: 3          # Health endpoint is fast, 3s is generous
  failureThreshold: 3        # 3 failures (15s total) before removing from service
```

**Liveness Probe:**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 5000
  initialDelaySeconds: 30    # Wait longer before first liveness check
  periodSeconds: 10          # Less frequent than readiness
  timeoutSeconds: 5          # Allow more time for potentially slow response
  failureThreshold: 3        # 3 failures (30s total) before restart
```

**Rationale:**
- **initialDelaySeconds** (readiness=10, liveness=30): Flask with Gunicorn takes ~8-10 seconds to fully initialize. Readiness starts at 10s to quickly add pod to service. Liveness waits 30s to avoid killing pods during initial database connection establishment.
- **periodSeconds** (readiness=5, liveness=10): Readiness checks more frequently to quickly detect when pod is ready to serve traffic. Liveness checks less frequently to reduce overhead.
- **timeoutSeconds** (readiness=3, liveness=5): Health endpoint is lightweight, but liveness gets more time to account for potential database connection delays.
- **failureThreshold** (both=3): Provides resilience against transient failures while still detecting real problems quickly (15s for readiness, 30s for liveness).

#### Nginx (07-nginx.yaml)

**Readiness Probe:**
```yaml
readinessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 5     # Nginx starts very quickly (~2-3s)
  periodSeconds: 5           # Frequent checks for fast traffic routing
  timeoutSeconds: 3          # Static content serves fast
  failureThreshold: 3        # 15s total before removing from service
```

**Liveness Probe:**
```yaml
livenessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 10    # Conservative, Nginx is stable
  periodSeconds: 10          # Less frequent checks
  timeoutSeconds: 5          # Allow time for backend proxy delays
  failureThreshold: 3        # 30s total before restart
```

**Rationale:**
- **initialDelaySeconds** (readiness=5, liveness=10): Nginx starts in 2-3 seconds. Readiness at 5s allows quick pod availability. Liveness at 10s is conservative.
- **periodSeconds** (readiness=5, liveness=10): Readiness checks frequently for traffic management. Liveness less frequent as Nginx is very stable.
- **timeoutSeconds** (readiness=3, liveness=5): Static files serve instantly, but liveness allows extra time for backend proxy health checks.

#### PostgreSQL (04-postgres.yaml)

```yaml
livenessProbe:
  exec:
    command: ["pg_isready", "-U", "$(POSTGRES_USER)"]
  initialDelaySeconds: 30    # PostgreSQL initialization can take 20-30s
  periodSeconds: 10          # Standard check frequency
  timeoutSeconds: 5          # pg_isready is fast but database may be busy
  failureThreshold: 6        # 60s total - avoid restart during heavy load
readinessProbe:
  exec:
    command: ["pg_isready", "-U", "$(POSTGRES_USER)"]
  initialDelaySeconds: 5     # Start checking early
  periodSeconds: 10          # Regular checks
  timeoutSeconds: 5          # Quick response expected
  failureThreshold: 3        # 30s before removing from service
```

**Rationale:**
- **initialDelaySeconds** (readiness=5, liveness=30): Database takes 20-30s for full initialization, recovery, and WAL replay. Readiness starts early to monitor startup progress.
- **failureThreshold** (readiness=3, liveness=6): Higher liveness threshold (60s) prevents unnecessary restarts during heavy query load or maintenance operations like VACUUM.

#### Redis (05-redis.yaml)

```yaml
livenessProbe:
  exec:
    command: ["redis-cli", "ping"]
  initialDelaySeconds: 30    # Allow time for AOF loading
  periodSeconds: 10          # Regular checks
  timeoutSeconds: 5          # PING is fast but allow buffer
  failureThreshold: 3        # 30s before restart
readinessProbe:
  exec:
    command: ["redis-cli", "ping"]
  initialDelaySeconds: 5     # Redis starts quickly
  periodSeconds: 10          # Standard check frequency
  timeoutSeconds: 5          # Fast response expected
  failureThreshold: 3        # 30s before removing
```

**Rationale:**
- **initialDelaySeconds** (readiness=5, liveness=30): Redis typically starts in <5s, but if AOF file is large, loading can take longer. Conservative liveness delay prevents premature restarts.
- **PING command**: Lightweight operation that confirms Redis is responsive without affecting performance.

### Rolling Update Strategy

The Flask application and Nginx are configured for zero-downtime rolling updates:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # Can create 1 extra pod (4 total during update)
    maxUnavailable: 0  # Cannot drop below 3 replicas - guarantees availability
```

**How it works:**
1. Start with 3 pods running v1
2. Create 1 new pod with v2 (4 pods total: 3×v1, 1×v2)
3. Wait for v2 pod to pass readiness probe
4. Terminate 1 v1 pod (3 pods remain: 2×v1, 1×v2)
5. Repeat until all pods are v2

**Rationale:**
- **maxSurge=1**: Infrastructure can accommodate 1 extra pod. This allows one new pod to fully start and pass health checks before terminating old pods.
- **maxUnavailable=0**: Requirement states service "cannot tolerate less replicas than declared". This ensures all 3 replicas remain available throughout the update.
- **Update time**: With probe settings, each pod takes ~15-20s to be ready. Full 3-pod update completes in ~60s with zero downtime.

## Common Commands

### Viewing Resources

```bash
# All resources
kubectl get all -n ecommerce

# Pods
kubectl get pods -n ecommerce

# Services
kubectl get svc -n ecommerce

# PVCs
kubectl get pvc -n ecommerce

# Ingress routes
kubectl get ingressroute -n ecommerce
```

### Viewing Logs

```bash
# All app logs
kubectl logs -n ecommerce -l app=flask-app -f

# Traefik logs (certificate status)
kubectl logs -n ecommerce -l app=traefik -f

# Database logs
kubectl logs -n ecommerce -l app=postgres -f

# Nginx logs
kubectl logs -n ecommerce -l app=nginx -f
```

### Scaling

```bash
# Scale Flask app
kubectl scale deployment app -n ecommerce --replicas=3

# Scale Nginx
kubectl scale deployment nginx -n ecommerce --replicas=3

# Check current replicas
kubectl get deployment -n ecommerce
```

### Debugging

```bash
# Describe pod (shows events)
kubectl describe pod -n ecommerce <pod-name>

# Execute command in pod
kubectl exec -it -n ecommerce <pod-name> -- /bin/bash

# Port forward for local testing
kubectl port-forward -n ecommerce svc/nginx 8080:80

# Check database connection
kubectl exec -n ecommerce <postgres-pod> -- pg_isready -U ecomuser

# Test Redis
kubectl exec -n ecommerce <redis-pod> -- redis-cli ping
```

### Restart Deployments

```bash
# Restart Flask app
kubectl rollout restart deployment app -n ecommerce

# Restart Nginx
kubectl rollout restart deployment nginx -n ecommerce

# Check rollout status
kubectl rollout status deployment app -n ecommerce
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n ecommerce

# Describe pod for events
kubectl describe pod -n ecommerce <pod-name>

# Check logs
kubectl logs -n ecommerce <pod-name>

# Check previous logs (if pod restarted)
kubectl logs -n ecommerce <pod-name> --previous
```

### Database Connection Issues

```bash
# Check if PostgreSQL is ready
kubectl exec -n ecommerce <postgres-pod> -- pg_isready -U ecomuser

# Check database logs
kubectl logs -n ecommerce -l app=postgres

# Test connection from app pod
kubectl exec -it -n ecommerce <app-pod> -- env | grep DB
```

### Certificate Not Issued

```bash
# Check Traefik logs for ACME errors
kubectl logs -n ecommerce -l app=traefik | grep -i acme

# Verify Cloudflare token is correct
kubectl get secret cloudflare-credentials -n ecommerce -o yaml

# Check DNS configuration
dig 2jz.space

# Verify domain points to LoadBalancer IP
kubectl get svc traefik -n ecommerce
```

### LoadBalancer Pending (Local Clusters)

**Minikube:**
```bash
minikube tunnel
# Keep this running in a separate terminal
```

**kind:**
```bash
# Use port-forward instead
kubectl port-forward -n ecommerce svc/traefik 8080:80 8443:443

# Access via http://localhost:8080
```

**k3s:**
k3s includes Traefik by default. You may need to disable the built-in Traefik:
```bash
k3s server --disable traefik
```

### Image Pull Errors

```bash
# If using private GHCR registry, create image pull secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<your-username> \
  --docker-password=<your-token> \
  --namespace=ecommerce

# Add to deployment in 06-app.yaml:
# spec:
#   template:
#     spec:
#       imagePullSecrets:
#       - name: ghcr-secret
```

## Persistence & Backups

### Persistent Volumes

Data is persisted using PersistentVolumeClaims:
- **postgres-pvc**: 5Gi - PostgreSQL data
- **redis-pvc**: 1Gi - Redis AOF persistence
- **traefik-acme-pvc**: 128Mi - Let's Encrypt certificates

### Database Backup

```bash
# Backup PostgreSQL
kubectl exec -n ecommerce <postgres-pod> -- pg_dump -U ecomuser ecommerce > backup.sql

# Restore PostgreSQL
cat backup.sql | kubectl exec -i -n ecommerce <postgres-pod> -- psql -U ecomuser ecommerce

# Copy files from pod
kubectl cp ecommerce/<postgres-pod>:/var/lib/postgresql/data ./postgres-backup/
```

### Redis Backup

```bash
# Redis uses AOF persistence, backed up automatically to PVC
# To manually save:
kubectl exec -n ecommerce <redis-pod> -- redis-cli BGSAVE

# Copy dump file
kubectl cp ecommerce/<redis-pod>:/data/dump.rdb ./redis-backup.rdb
```

## Cleanup

### Remove Everything

Using the script:
```bash
./uninstall.sh
```

Manual cleanup:
```bash
# Delete namespace (removes all resources)
kubectl delete namespace ecommerce

# Optionally remove Traefik CRDs
kubectl delete crd ingressroutes.traefik.io
kubectl delete crd middlewares.traefik.io
kubectl delete crd tlsoptions.traefik.io
# ... (see uninstall.sh for full list)

# Remove ClusterRole and ClusterRoleBinding
kubectl delete clusterrole traefik-role
kubectl delete clusterrolebinding traefik-role-binding
```

### Orphaned PersistentVolumes

Check for orphaned PVs:
```bash
kubectl get pv | grep ecommerce
```

Delete if found:
```bash
kubectl delete pv <pv-name>
```

## Security Considerations

1. **Secrets Management**
   - Secrets are base64 encoded (not encrypted at rest by default)
   - Consider using external secret management (HashiCorp Vault, AWS Secrets Manager, etc.)
   - Rotate credentials regularly

2. **RBAC**
   - Traefik uses minimal ClusterRole permissions
   - Review [08-traefik-config.yaml](08-traefik-config.yaml) for RBAC configuration

3. **Network Policies**
   - Not implemented by default
   - Consider adding NetworkPolicies to restrict pod-to-pod communication

4. **Image Security**
   - All images should use specific tags (not `latest`) in production
   - Scan images for vulnerabilities regularly
   - Use private registries for custom images

5. **Security Headers**
   - Nginx includes security headers (X-Frame-Options, X-XSS-Protection, etc.)
   - See [02-configmaps.yaml](02-configmaps.yaml) for configuration

6. **Resource Limits**
   - All deployments have CPU and memory limits
   - Prevents resource exhaustion attacks

## Production Recommendations

### Before Production

- [ ] Use specific image tags (not `latest`)
- [ ] Set up monitoring (Prometheus + Grafana)
- [ ] Configure log aggregation (ELK, Loki, CloudWatch)
- [ ] Implement Horizontal Pod Autoscaling
- [ ] Set up pod disruption budgets
- [ ] Configure resource quotas for namespace
- [ ] Add NetworkPolicies
- [ ] Set up automated backups for PostgreSQL
- [ ] Use external secrets management
- [ ] Implement CI/CD pipeline
- [ ] Set up separate environments (dev, staging, prod)
- [ ] Configure monitoring alerts
- [ ] Document runbooks for common issues

### Recommended Tools

- **Monitoring**: Prometheus Operator, Grafana
- **Logging**: Loki, ELK Stack, Fluent Bit
- **CI/CD**: GitHub Actions, GitLab CI, ArgoCD
- **Secrets**: Sealed Secrets, External Secrets Operator, Vault
- **Backup**: Velero, Stash
- **Security**: Falco, Trivy, Snyk

## Migration from Docker Compose

This deployment is migrated from the Docker Compose setup in `docker/` folder.

| Docker Compose | Kubernetes |
|----------------|------------|
| `db` service | [04-postgres.yaml](04-postgres.yaml) |
| `redis` service | [05-redis.yaml](05-redis.yaml) |
| `app` service | [06-app.yaml](06-app.yaml) |
| `nginx` service | [07-nginx.yaml](07-nginx.yaml) |
| `certbot` + `certbot-renew` | [08-traefik-config.yaml](08-traefik-config.yaml) |
| Docker volumes | [03-pvcs.yaml](03-pvcs.yaml) |
| Docker secrets | [01-secrets.yaml](01-secrets.yaml) |

**Key Change:** Certbot replaced with Traefik for automatic certificate management.

See [MIGRATION.md](MIGRATION.md) for detailed migration information.

## API Endpoints

Once deployed, the following endpoints are available:

### Health Check
```bash
curl https://2jz.space/health
```

Response:
```json
{
  "status": "healthy",
  "database": "connected",
  "redis": "connected",
  "nginx": "ok"
}
```

### List Products
```bash
curl https://2jz.space/products
```

### Add Product
```bash
curl -X POST https://2jz.space/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop","price":999.99}'
```

### Update Product
```bash
curl -X PUT https://2jz.space/products/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Gaming Laptop","price":1299.99}'
```

### Delete Product
```bash
curl -X DELETE https://2jz.space/products/1
```

## License

This is an educational DevOps project. Use at your own discretion.

## Support

- **Documentation**: [QUICKSTART.md](QUICKSTART.md), [MIGRATION.md](MIGRATION.md)
- **Traefik Docs**: https://doc.traefik.io/traefik/
- **Kubernetes Docs**: https://kubernetes.io/docs/
- **PostgreSQL Docs**: https://www.postgresql.org/docs/
- **Redis Docs**: https://redis.io/documentation

## Changelog

- **v2.0** - Migrated to Kubernetes with Traefik
- **v1.0** - Initial Docker Compose implementation

---

**Ready to deploy?** Run `./deploy.sh` to get started!
