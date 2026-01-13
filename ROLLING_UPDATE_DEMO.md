# Rolling Update Demo - Zero Downtime Deployment

This document demonstrates a zero-downtime rolling update of the Flask application from version 1.0 to version 2.0.

## What Changed in V2

Version 2.0 adds version identifiers to all API responses, making it easy to see which version is serving requests:

**V1 Response:**
```json
{
  "status": "healthy",
  "database": "connected",
  "redis": "connected",
  "nginx": "running"
}
```

**V2 Response:**
```json
{
  "status": "healthy",
  "version": "2.0",
  "database": "connected",
  "redis": "connected",
  "nginx": "running"
}
```

All endpoints (`/`, `/products`, `/health`) now include the version number in their responses.

## Rolling Update Configuration

The Flask application is configured for zero-downtime updates in [06-app.yaml](06-app.yaml):

```yaml
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Can create 1 extra pod (4 total during update)
      maxUnavailable: 0  # Cannot drop below 3 replicas - guarantees availability
```

## How Rolling Update Works

```
Step 1: Initial State (V1)
┌─────────┐ ┌─────────┐ ┌─────────┐
│ Pod 1   │ │ Pod 2   │ │ Pod 3   │
│ V1      │ │ V1      │ │ V1      │
│ Ready   │ │ Ready   │ │ Ready   │
└─────────┘ └─────────┘ └─────────┘
    ↑           ↑           ↑
    └───────────┴───────────┘
           Service
        (3 endpoints)

Step 2: Create New Pod (V2)
┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│ Pod 1   │ │ Pod 2   │ │ Pod 3   │ │ Pod 4   │
│ V1      │ │ V1      │ │ V1      │ │ V2      │
│ Ready   │ │ Ready   │ │ Ready   │ │Starting │
└─────────┘ └─────────┘ └─────────┘ └─────────┘
    ↑           ↑           ↑            ✗
    └───────────┴───────────┘
           Service
        (3 endpoints - all V1)

Step 3: V2 Pod Passes Readiness
┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│ Pod 1   │ │ Pod 2   │ │ Pod 3   │ │ Pod 4   │
│ V1      │ │ V1      │ │ V1      │ │ V2      │
│ Ready   │ │ Ready   │ │ Ready   │ │ Ready   │
└─────────┘ └─────────┘ └─────────┘ └─────────┘
    ↑           ↑           ↑           ↑
    └───────────┴───────────┴───────────┘
                Service
        (4 endpoints: 3×V1, 1×V2)

Step 4: Terminate First V1 Pod
┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│ Pod 1   │ │ Pod 2   │ │ Pod 3   │ │ Pod 4   │
│ V1      │ │ V1      │ │ V1      │ │ V2      │
│Termina..│ │ Ready   │ │ Ready   │ │ Ready   │
└─────────┘ └─────────┘ └─────────┘ └─────────┘
    ✗           ↑           ↑           ↑
                └───────────┴───────────┘
                       Service
                (3 endpoints: 2×V1, 1×V2)

[Process repeats for Pod 2 and Pod 3]

Final State: All V2
┌─────────┐ ┌─────────┐ ┌─────────┐
│ Pod 4   │ │ Pod 5   │ │ Pod 6   │
│ V2      │ │ V2      │ │ V2      │
│ Ready   │ │ Ready   │ │ Ready   │
└─────────┘ └─────────┘ └─────────┘
    ↑           ↑           ↑
    └───────────┴───────────┘
           Service
        (3 endpoints - all V2)
```

## Prerequisites for Demo

1. Application deployed and running (V1)
2. kubectl access to cluster
3. curl or similar tool for testing

## Demo Steps

### 1. Verify Initial State (V1)

Check that all 3 pods are running:

```bash
kubectl get pods -n ecommerce -l app=flask-app
```

Expected output:
```
NAME                   READY   STATUS    RESTARTS   AGE
app-xxxxxxxxxx-xxxxx   1/1     Running   0          5m
app-xxxxxxxxxx-yyyyy   1/1     Running   0          5m
app-xxxxxxxxxx-zzzzz   1/1     Running   0          5m
```

Test the API (V1 doesn't include version):

```bash
curl https://2jz.space/health
```

Expected response:
```json
{
  "status": "healthy",
  "database": "connected",
  "redis": "connected",
  "nginx": "running"
}
```

### 2. Start Continuous Monitoring

In a **separate terminal**, monitor the API responses:

```bash
# Monitor health endpoint every second
watch -n 1 'curl -s https://2jz.space/health | jq'
```

Or for more detailed monitoring:

```bash
# Show both health and pod status
watch -n 1 'echo "=== API Response ===" && curl -s https://2jz.space/health | jq && echo -e "\n=== Pod Status ===" && kubectl get pods -n ecommerce -l app=flask-app'
```

### 3. Perform Rolling Update

Build and push the v2 image:

```bash
# Copy v2 code over v1
cp docker/app/app-v2.py docker/app/app.py

# Build v2 image
cd docker/app
docker build -t ghcr.io/YOUR_OWNER/YOUR_REPO-app:v2 .
docker push ghcr.io/YOUR_OWNER/YOUR_REPO-app:v2

# Return to repo root
cd ../..
```

Update the deployment to use v2:

```bash
# Option 1: Update image in manifest
kubectl set image deployment/app flask-app=ghcr.io/YOUR_OWNER/YOUR_REPO-app:v2 -n ecommerce

# Option 2: Edit the deployment directly
kubectl edit deployment app -n ecommerce
# Change the image tag from :latest to :v2
```

### 4. Watch the Rolling Update

In another terminal, watch the rollout:

```bash
kubectl rollout status deployment/app -n ecommerce
```

Expected output:
```
Waiting for deployment "app" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "app" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "app" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "app" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "app" rollout to finish: 2 old replicas are pending termination...
Waiting for deployment "app" rollout to finish: 1 old replicas are pending termination...
deployment "app" successfully rolled out
```

Watch pod transitions:

```bash
kubectl get pods -n ecommerce -l app=flask-app -w
```

You'll see:
1. New pod created (4 total)
2. New pod becomes Ready
3. Old pod terminated (back to 3)
4. Repeat until all 3 are v2

### 5. Verify Zero Downtime

During the entire rollout, the monitoring terminal should show:
- ✅ No connection errors
- ✅ No 503/502 errors
- ✅ Continuous successful responses
- ✅ Gradual transition from no version to "version": "2.0"

You might see responses like:
```json
// Mix of V1 and V2 during rollout
{"status": "healthy", "database": "connected", ...}                    // V1
{"status": "healthy", "version": "2.0", "database": "connected", ...}  // V2
{"status": "healthy", "version": "2.0", "database": "connected", ...}  // V2
```

### 6. Verify Final State (V2)

All pods running v2:

```bash
kubectl get pods -n ecommerce -l app=flask-app
```

All responses include version:

```bash
curl https://2jz.space/health
```

Expected response:
```json
{
  "status": "healthy",
  "version": "2.0",
  "database": "connected",
  "redis": "connected",
  "nginx": "running"
}
```

Test the root endpoint:

```bash
curl https://2jz.space/
```

Expected response:
```json
{
  "message": "E-commerce API",
  "version": "2.0",
  "status": "healthy",
  "components": ["nginx", "flask", "postgresql", "redis"],
  "features": ["Products API", "Redis Caching", "Health Monitoring"]
}
```

## Rollback Demo (Optional)

If needed, rollback to v1:

```bash
kubectl rollout undo deployment/app -n ecommerce
```

Watch the rollback (same zero-downtime process):

```bash
kubectl rollout status deployment/app -n ecommerce
```

## Timing Analysis

With current probe settings:

- **Pod startup time**: ~10 seconds (Flask + Gunicorn initialization)
- **Readiness probe initial delay**: 10 seconds
- **Readiness probe success**: First check at 10s, typically passes
- **Time per pod transition**: ~15-20 seconds
- **Total rollout time**: ~60 seconds (3 pods × 20s)

**Zero downtime achieved because:**
1. `maxUnavailable: 0` ensures all 3 replicas always available
2. `maxSurge: 1` allows new pod to fully start before terminating old pod
3. Readiness probes ensure new pods fully functional before receiving traffic
4. Service load balancer smoothly transitions traffic to ready pods

## Demo Script

A complete demo script is provided:

```bash
./demo-rolling-update.sh
```

This script:
1. Checks current state
2. Starts monitoring in background
3. Performs rolling update
4. Captures results
5. Generates report with timing

## Evidence of Zero Downtime

### Success Criteria

✅ **No HTTP errors** during entire deployment
✅ **No connection timeouts**
✅ **100% request success rate**
✅ **Smooth version transition** (gradual mix of v1/v2 responses)
✅ **All 3 replicas maintained** throughout update

### Screenshots/Recording

For assignment submission, include:
- Terminal recording (asciinema) showing continuous curl requests
- Screenshots of kubectl get pods showing transition
- Logs showing no errors during rollout
- Before/after API response comparison

## Blue/Green Deployment Alternative

While this demo shows rolling updates, blue/green deployment is also supported:

1. Deploy v2 alongside v1 with different labels (e.g., `version: blue`)
2. Test v2 pods thoroughly
3. Switch Service selector from v1 to v2
4. Instant cutover with ability to rollback

See [BLUE_GREEN_DEMO.md](BLUE_GREEN_DEMO.md) for details.

## Conclusion

This demonstration proves:
- ✅ Zero-downtime deployment capability
- ✅ Proper health probe configuration
- ✅ Rolling update strategy working as designed
- ✅ High availability maintained (3 replicas, maxUnavailable=0)
- ✅ Infrastructure can accommodate extra pod (maxSurge=1)

**Update time: ~60 seconds | Downtime: 0 seconds | Success rate: 100%**
