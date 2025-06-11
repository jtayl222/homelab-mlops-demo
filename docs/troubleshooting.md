# MLOps Pipeline Troubleshooting Guide

This document covers common issues you might encounter when running the MLOps pipeline and how to resolve them.

## Model Deployment Issues

### ImagePullBackOff Error

**Problem:**
```bash
$ kubectl get pods -n argowf -l seldon-deployment-id=iris
NAME                                         READY   STATUS             RESTARTS   AGE
iris-default-0-classifier-85d56cc6b6-qsjpr   0/2     ImagePullBackOff   0          56m
```

**Diagnosis:**
```bash
# Check what image the pod is trying to pull
kubectl describe pod -n argowf -l seldon-deployment-id=iris

# Look for events showing the image pull failure
kubectl get events -n argowf --sort-by='.lastTimestamp' | grep -i pull
```

**Common Causes & Solutions:**

1. **Image doesn't exist in registry:**
   - Check if Kaniko build step completed successfully: `argo logs iris-demo -n argowf --container kaniko`
   - Verify image was pushed to your registry (MinIO or external)

2. **Registry authentication issues:**
   ```bash
   # Check if registry secrets exist
   kubectl get secrets -n argowf | grep registry
   
   # Verify Seldon deployment has access to registry credentials
   kubectl describe seldondeployment iris -n argowf
   ```

3. **Wrong image name/tag:**
   ```bash
   # Check what image name was used in deployment
   kubectl get seldondeployment iris -n argowf -o yaml | grep image
   
   # Compare with what Kaniko built
   argo logs iris-demo -n argowf --container kaniko | grep "Pushing image"
   ```

**Quick Fix:**
If the build step succeeded but deployment failed, try deleting and recreating the Seldon deployment:
```bash
kubectl delete seldondeployment iris -n argowf
# Re-run the workflow or just the deploy step
```

## Service Port Issues

### Wrong Service Port for Testing

**Problem:**
```bash
$ kubectl port-forward -n argowf svc/iris-default 8080:8080 &
error: Service iris-default does not have a service port 8080
```

**Solution:**
Check the actual service ports and use the correct one:
```bash
# Check service ports
kubectl get svc iris-default -n argowf
kubectl describe svc iris-default -n argowf

# Example output:
# NAME           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
# iris-default   ClusterIP   10.43.247.226   <none>        8000/TCP,5001/TCP   59m

# Use the correct port (8000 in this case)
kubectl port-forward -n argowf svc/iris-default 8080:8000 &

# Test the endpoint
curl -X POST http://localhost:8080/api/v1.0/predictions \
  -H "Content-Type: application/json" \
  -d '{"data": {"ndarray": [[5.1, 3.5, 1.4, 0.2]]}}'
```

**Common Seldon Service Ports:**
- `8000`: Main prediction endpoint
- `5001`: Metrics endpoint  
- `9000`: Internal classifier endpoint
- `9500`: Internal metrics endpoint

## MLflow Access Issues

### MLflow Port Forward Not Working

**Problem:**
```bash
$ kubectl port-forward -n mlflow svc/mlflow 5000:5000 &
# Fails or times out
```

**Diagnosis:**
```bash
# Check if MLflow namespace exists
kubectl get namespaces | grep mlflow

# Check if MLflow service exists and its ports
kubectl get svc -n mlflow

# If MLflow is in a different namespace or has different service name:
kubectl get svc -A | grep mlflow
```

**Solution for External MLflow Access:**

If your MLflow is accessible at `http://192.168.1.85:30800/`, you don't need port forwarding:

```bash
# Direct access to MLflow (no port-forward needed)
echo "MLflow UI available at: http://192.168.1.85:30800/"

# Check experiments via API
curl -s "http://192.168.1.85:30800/api/2.0/mlflow/experiments/list" | jq .

# Check if your training runs are logged
curl -s "http://192.168.1.85:30800/api/2.0/mlflow/experiments/get-by-name?experiment_name=iris-classification" | jq .
```

**Alternative MLflow Setup:**
If MLflow isn't properly integrated, check your training script logs:
```bash
# Check if train.py successfully logged to MLflow
argo logs iris-demo -n argowf --container train | grep -i mlflow

# Common issues:
# - MLflow tracking URI not set correctly
# - Network connectivity to MLflow server
# - Authentication issues
```

## Workflow Execution Issues

### Workflow Stuck in Running State

**Problem:**
```bash
$ argo get iris-demo -n argowf
Status: Running
# Workflow never completes
```

**Diagnosis:**
```bash
# Check which step is stuck
argo get iris-demo -n argowf -o wide

# Check pod status for the running step
kubectl get pods -n argowf | grep iris-demo

# Get detailed pod information
kubectl describe pod <stuck-pod-name> -n argowf

# Check pod logs
kubectl logs <stuck-pod-name> -n argowf --all-containers
```

**Common Causes:**
1. **Resource constraints**: Pod pending due to insufficient CPU/memory
2. **Image pull issues**: Container can't start due to image problems
3. **Volume mount failures**: ConfigMap or PVC not available
4. **Network issues**: Can't reach external services (MLflow, registry)

### Artifact Repository Errors

**Problem:**
```bash
Error (exit code 64): You need to configure artifact storage
```

**Solution:**
Check and fix the artifact repository configuration:
```bash
# Check current workflow controller config
kubectl get configmap workflow-controller-configmap -n argowf -o yaml

# Verify MinIO credentials exist
kubectl get secret minio-credentials-wf -n argowf

# Test MinIO connectivity
kubectl run -it --rm debug --image=minio/mc -- \
  mc alias set myminio http://minio.minio.svc.cluster.local:9000 \
  <access-key> <secret-key>
```

## Permission and Security Issues

### Pod Security Context Failures

**Problem:**
```bash
# Pod fails with permission denied errors
Error: cannot write to /output directory
```

**Solution:**
Check the security context in your workflow:
```bash
# Verify security context is set correctly
kubectl get workflow iris-demo -n argowf -o yaml | grep -A 5 securityContext

# Should show:
# securityContext:
#   runAsUser: 0
#   runAsGroup: 0
```

**Common Security Fixes:**
```yaml
# In workflow.yaml template
securityContext:
  runAsUser: 0      # Root user for initial setup
  runAsGroup: 0     # Root group
  fsGroup: 100      # For shared volume access
```

## Storage and Volume Issues

### NFS Mount Failures

**Problem:**
```bash
MountVolume.SetUp failed for volume "workdir"
```

**Diagnosis:**
```bash
# Check NFS storage class
kubectl get storageclass nfs-shared

# Check PVC status
kubectl get pvc -n argowf

# Check NFS provisioner logs
kubectl logs -n kube-system -l app=csi-driver-nfs
```

**Solution:**
```bash
# Verify NFS server is accessible
kubectl run -it --rm nfs-test --image=busybox -- nslookup <nfs-server-ip>

# Check PVC creation
kubectl describe pvc <pvc-name> -n argowf

# If PVC is stuck, delete and recreate workflow
argo delete iris-demo -n argowf --force
argo submit demo_iris_pipeline/workflow.yaml -n argowf
```

## ConfigMap Issues

### Source Code Not Found

**Problem:**
```bash
MountVolume.SetUp failed for volume "src" : configmap "iris-src" not found
```

**Solution:**
```bash
# Create the ConfigMap
kubectl create configmap iris-src \
  --from-file=train.py=demo_iris_pipeline/train.py \
  --from-file=serve.py=demo_iris_pipeline/serve.py \
  --from-file=Dockerfile=demo_iris_pipeline/Dockerfile \
  --from-file=requirements.txt=demo_iris_pipeline/requirements.txt \
  -n argowf

# Or use the update script
./update-configmap.sh

# Verify ConfigMap exists
kubectl get configmap iris-src -n argowf -o yaml
```

## GitOps and ArgoCD Issues

### Local Changes Being Overwritten by ArgoCD

**Problem:**
You update your workflow.yaml locally and apply it, but changes don't persist or get reverted:

```bash
# You make changes locally
vim demo_iris_pipeline/workflow.yaml
# Remove --no-push flag, add registry credentials, etc.

# Apply them locally  
kubectl apply -f demo_iris_pipeline/workflow.yaml

# But workflow still shows old behavior
argo logs iris-demo -n argowf --container main | grep "no-push"
# Still shows: INFO[0077] Skipping push to container registry due to --no-push flag
```

**Root Cause:**
ArgoCD manages your workflow from Git and continuously syncs from the repository. Local `kubectl apply` changes are **temporary** and get overwritten by ArgoCD's sync cycle (every ~3 minutes).

**Solution - Proper GitOps Workflow:**
```bash
# 1. Make changes locally
vim demo_iris_pipeline/workflow.yaml

# 2. Commit and push to Git (this is the key step!)
git add demo_iris_pipeline/workflow.yaml
git commit -m "Remove --no-push flag to enable GHCR push"
git push origin main

# 3. Wait for or force ArgoCD sync
argocd app sync homelab-mlops-demo

# 4. Verify changes took effect
kubectl get workflow iris-demo -n argowf -o yaml | grep -A 10 kaniko
```

**Quick Diagnostic:**
```bash
# Check what Git commit ArgoCD is synced to
argocd app get homelab-mlops-demo | grep "Sync Revision"

# Compare with your latest local commit
git log --oneline -1

# If they don't match, ArgoCD hasn't synced your latest changes
```

### Local Changes Being Overwritten by ArgoCD

**Problem:**
You update your workflow.yaml locally and apply it, but changes don't persist or get reverted:

```bash
# You make changes locally
vim demo_iris_pipeline/workflow.yaml
# Remove --no-push flag, add registry credentials, etc.

# Apply them locally  
kubectl apply -f demo_iris_pipeline/workflow.yaml

# But workflow still shows old behavior
argo logs iris-demo -n argowf --container main | grep "no-push"
# Still shows: INFO[0077] Skipping push to container registry due to --no-push flag
```

**Root Cause:**
ArgoCD manages your workflow from Git and continuously syncs from the repository. Local `kubectl apply` changes are **temporary** and get overwritten by ArgoCD's sync cycle (every ~3 minutes).

**Solution - Proper GitOps Workflow:**
```bash
# 1. Make changes locally
vim demo_iris_pipeline/workflow.yaml

# 2. Commit and push to Git (this is the key step!)
git add demo_iris_pipeline/workflow.yaml
git commit -m "Remove --no-push flag to enable GHCR push"
git push origin main

# 3. Wait for or force ArgoCD sync
argocd app sync homelab-mlops-demo

# 4. Verify changes took effect
kubectl get workflow iris-demo -n argowf -o yaml | grep -A 10 kaniko
```

**Quick Diagnostic:**
```bash
# Check what Git commit ArgoCD is synced to
argocd app get homelab-mlops-demo | grep "Sync Revision"

# Compare with your latest local commit
git log --oneline -1

# If they don't match, ArgoCD hasn't synced your latest changes

### ArgoCD Application Out of Sync

**Problem:**
```bash
$ argocd app get argocd/homelab-mlops-demo
Sync Status: OutOfSync
```

**Solution:**
```bash
# Force sync the application
argocd app sync argocd/homelab-mlops-demo

# If sync fails, check for conflicts
argocd app manifests argocd/homelab-mlops-demo | kubectl apply --dry-run=client -f -

# Check ArgoCD application health
argocd app get argocd/homelab-mlops-demo --show-params
```

### Git Repository Access Issues

**Problem:**
ArgoCD can't access your Git repository.

**Solution:**
```bash
# Check repository credentials
argocd repo list

# Add repository if missing (for public repos)
argocd repo add https://github.com/jtayl222/homelab-mlops-demo.git

# For private repos, add SSH key or token
argocd repo add https://github.com/jtayl222/homelab-mlops-demo.git \
  --username <username> --password <token>
```

## Performance and Resource Issues

### Slow Pipeline Execution

**Problem:**
Pipeline takes much longer than expected (>10 minutes).

**Diagnosis:**
```bash
# Check resource usage
kubectl top pods -n argowf

# Check node resources
kubectl describe nodes

# Check for resource limits
argo get iris-demo -n argowf -o yaml | grep -A 5 resources
```

**Solutions:**
1. **Increase resource limits** in workflow.yaml
2. **Check node capacity**: `kubectl describe nodes | grep -A 5 "Allocated resources"`
3. **Monitor storage performance**: NFS can be slow for large datasets

### Out of Memory Errors

**Problem:**
```bash
Pod killed due to OOMKilled
```

**Solution:**
```bash
# Increase memory limits in workflow.yaml
resources:
  requests:
    memory: "4Gi"
    cpu: "1"
  limits:
    memory: "8Gi"  # Increase this
    cpu: "2"

# Check memory usage patterns
kubectl top pod <pod-name> -n argowf --containers
```

## Debugging Commands Reference

### Essential Debugging Commands
```bash
# Pipeline status
argo get iris-demo -n argowf
argo logs iris-demo -n argowf

# Pod debugging
kubectl get pods -n argowf
kubectl describe pod <pod-name> -n argowf
kubectl logs <pod-name> -n argowf --all-containers

# Service debugging
kubectl get svc -n argowf
kubectl describe svc <service-name> -n argowf

# Resource debugging
kubectl get events -n argowf --sort-by='.lastTimestamp'
kubectl top pods -n argowf
kubectl get pvc -n argowf

# ArgoCD debugging
argocd app get argocd/homelab-mlops-demo
argocd app manifests argocd/homelab-mlops-demo
```

### Log Analysis
```bash
# Search for specific errors
argo logs iris-demo -n argowf | grep -i error
kubectl logs <pod-name> -n argowf | grep -i "failed\|error\|timeout"

# Check container startup
kubectl logs <pod-name> -n argowf -c init --previous

# Monitor real-time logs
kubectl logs -f <pod-name> -n argowf --all-containers
```

## Container and Pod Debugging

### Finding Container Names in Pods

**Problem:**
You need to debug a specific container but don't know the container names.

**Solution:**
```bash
# List all containers in a pod
kubectl get pod <pod-name> -n argowf -o jsonpath='{.spec.containers[*].name}'

# Example: Check containers in a Seldon pod
kubectl get pod iris-default-0-classifier-564d447d7b-jskd7 -n argowf -o jsonpath='{.spec.containers[*].name}'
# Output: seldon-container-engine classifier

# Get detailed container info including status
kubectl describe pod <pod-name> -n argowf | grep -A 5 "Containers:"

# For multi-container pods, see container status
kubectl get pod <pod-name> -n argowf -o yaml | grep -A 10 containerStatuses
```

### Getting Logs from Specific Containers

**Problem:**
Default kubectl logs shows mixed output from all containers, making it hard to debug specific issues.

**Solutions:**
```bash
# Get logs from a specific container
kubectl logs <pod-name> -n argowf -c <container-name>

# Example: Get logs from just the classifier container
kubectl logs iris-default-0-classifier-564d447d7b-jskd7 -n argowf -c classifier

# Get logs from just the seldon-container-engine
kubectl logs iris-default-0-classifier-564d447d7b-jskd7 -n argowf -c seldon-container-engine

# Use labels to get logs from multiple pods with same container
kubectl logs -l seldon-app=iris-default -n argowf -c classifier

# Follow logs in real-time from specific container
kubectl logs -f <pod-name> -n argowf -c <container-name>
```

### Workflow Container Name Issues

**Problem:**
Argo workflow container names don't match what you expect:

```bash
$ argo logs iris-demo -n argowf --container kaniko
ERRO[2025-06-11T09:14:38.011Z] container kaniko is not valid for pod
```

**Root Cause:**
Argo workflows use `main` as the default container name, not the template name.

**Solution:**
```bash
# Use 'main' instead of the template name
argo logs iris-demo -n argowf --container main

# Or get logs from specific workflow pods directly
kubectl logs iris-demo-kaniko-2925953904 -n argowf -c main

# List all containers in a workflow pod
kubectl get pod iris-demo-kaniko-2925953904 -n argowf -o jsonpath='{.spec.containers[*].name}'
# Output: init main wait

# Get logs from the correct container
kubectl logs iris-demo-kaniko-2925953904 -n argowf -c main
```

### Managing Large Log Volumes

**Problem:**
Workflow logs are too large to analyze effectively:

```bash
$ argo logs iris-demo -n argowf | wc -l
583
$ argo logs iris-demo -n argowf > logs.txt
$ du -k logs.txt
2944 logs.txt  # 3MB is too much for human consumption
```

**Solutions:**
```bash
# Filter logs for specific information
argo logs iris-demo -n argowf | grep -i "error\|failed\|warning"

# Get logs from specific step only
kubectl logs iris-demo-kaniko-2925953904 -n argowf -c main

# Get last N lines of logs
argo logs iris-demo -n argowf --tail=50

# Search for specific patterns
argo logs iris-demo -n argowf | grep -i "pushing\|pushed\|ghcr"

# Get logs since specific time
kubectl logs iris-demo-kaniko-2925953904 -n argowf -c main --since=10m

# Analyze logs by step
echo "=== Train Step ==="
kubectl logs iris-demo-train-1086554222 -n argowf -c main | tail -20
echo "=== Build Step ==="
kubectl logs iris-demo-kaniko-2925953904 -n argowf -c main | tail -20
echo "=== Deploy Step ==="
kubectl logs iris-demo-deploy-2552441111 -n argowf -c main | tail -20
```

### Testing Container Connectivity

**Problem:**
You need to test if your application is actually working inside the container, but tools like `curl` might not be available.

**Solutions:**
```bash
# Test HTTP endpoints using Python (usually available in Python containers)
kubectl exec -n argowf <pod-name> -c <container-name> -- python -c "
import urllib.request
response = urllib.request.urlopen('http://localhost:8080/health')
print(response.read().decode('utf-8'))
"

# Example: Test your FastAPI health endpoint
kubectl exec -n argowf iris-default-0-classifier-564d447d7b-jskd7 -c classifier -- python -c "
import urllib.request
response = urllib.request.urlopen('http://localhost:8080/health')
print(response.read().decode('utf-8'))
"

# Test with wget if available
kubectl exec -n argowf <pod-name> -c <container-name> -- wget -qO- http://localhost:8080/health

# Test TCP connectivity
kubectl exec -n argowf <pod-name> -c <container-name> -- nc -z localhost 8080
echo $?  # 0 means success

# Check what processes are running and listening
kubectl exec -n argowf <pod-name> -c <container-name> -- ps aux
kubectl exec -n argowf <pod-name> -c <container-name> -- netstat -tlnp
```

### Container Status Troubleshooting

**Quick Container Health Check:**
```bash
# Check container ready status
kubectl get pod <pod-name> -n argowf -o jsonpath='{.status.containerStatuses[*].ready}'

# Check container restart count
kubectl get pod <pod-name> -n argowf -o jsonpath='{.status.containerStatuses[*].restartCount}'

# Get container state details
kubectl get pod <pod-name> -n argowf -o jsonpath='{.status.containerStatuses[*].state}'

# Example: Check specific Seldon containers
kubectl get pod iris-default-0-classifier-564d447d7b-jskd7 -n argowf -o yaml | grep -A 20 containerStatuses
```

### Efficient Log Analysis Workflow

**Step-by-step debugging approach:**
```bash
# 1. Identify the problem pod
kubectl get pods -n argowf | grep -E "(Error|CrashLoop|ImagePull)"

# 2. Check container names
kubectl get pod <pod-name> -n argowf -o jsonpath='{.spec.containers[*].name}'

# 3. Check container status
kubectl describe pod <pod-name> -n argowf | grep -A 10 "Container States"

# 4. Get recent logs from each container
for container in $(kubectl get pod <pod-name> -n argowf -o jsonpath='{.spec.containers[*].name}'); do
  echo "=== Container: $container ==="
  kubectl logs <pod-name> -n argowf -c $container --tail=20
  echo ""
done

# 5. Test connectivity if container is running
kubectl exec -n argowf <pod-name> -c <container-name> -- python -c "
import urllib.request
try:
    response = urllib.request.urlopen('http://localhost:8080/health')
    print('✅ Health check passed:', response.read().decode('utf-8'))
except Exception as e:
    print('❌ Health check failed:', str(e))
"
```

### Container Resource Debugging

**Check if containers are resource-constrained:**
```bash
# Check current resource usage
kubectl top pod <pod-name> -n argowf --containers

# Check resource limits vs usage
kubectl describe pod <pod-name> -n argowf | grep -A 10 -B 5 "Limits\|Requests"

# Check for OOMKilled events
kubectl get events -n argowf --field-selector involvedObject.name=<pod-name> | grep -i "oom\|killed"
```

This systematic approach helps you quickly identify which container is failing and why, especially in complex multi-container pods like Seldon deployments.

## Recovery Procedures

### Complete Pipeline Reset
```bash
# Delete failed workflow
argo delete iris-demo -n argowf --force

# Clean up stuck resources
kubectl delete pods -n argowf -l workflows.argoproj.io/workflow=iris-demo

# Recreate ConfigMap
kubectl delete configmap iris-src -n argowf
./update-configmap.sh

# Restart workflow
argo submit demo_iris_pipeline/workflow.yaml -n argowf --watch
```

### Seldon Deployment Reset
```bash
# Delete Seldon deployment
kubectl delete seldondeployment iris -n argowf

# Clean up associated resources
kubectl delete svc iris-default iris-default-classifier -n argowf
kubectl delete pods -n argowf -l seldon-deployment-id=iris

# Re-run deploy step or full workflow
```

### Emergency Cluster Reset
```bash
# If everything is broken, reset the namespace
kubectl delete namespace argowf
kubectl create namespace argowf

# Recreate necessary secrets and configs
# Re-run ArgoCD sync
argocd app sync argocd/homelab-mlops-demo --force
```

## Container Registry Issues

*Problem*: `ImagePullBackOff` with GHCR authentication errors
```
failed to authorize: failed to fetch anonymous token: 403 Forbidden
```

*Solutions*:
1. **Make GHCR repository public** (GitHub repo settings → Packages → Change visibility)
2. **Use Docker Hub instead**: Change image tag in workflow to `docker.io/username/iris:latest`
3. **Add registry authentication**: Create docker-registry secret as shown above
4. **Use local registry**: Configure MinIO or Harbor for internal image storage

*Current Implementation*: This demo uses `--no-push` with Kaniko to avoid registry authentication complexity, building images locally within the workflow.

Remember: Most issues can be resolved by checking logs, verifying configurations, and ensuring all dependencies (MinIO, MLflow, NFS) are accessible and properly configured.

## GHCR Push/Pull Mismatch Issue

### The Problem
Your workflow shows this sequence:
1. ✅ **Workflow succeeded** - Kaniko build completed
2. ✅ **Seldon deployment created** - Deploy step succeeded  
3. ❌ **Pod fails with ImagePullBackOff** - Can't pull from GHCR

**Root Cause**: Kaniko built the image but didn't push it to GHCR because it lacks registry credentials, yet your Seldon deployment tries to pull from GHCR.

### Quick Diagnosis
```bash
# Check if workflow completed successfully
argo get iris-demo -n argowf
# Should show: Status: Succeeded

# Check if image was actually pushed to GHCR
argo logs iris-demo -n argowf --container kaniko | grep -i "pushing\|pushed\|error"

# Check Seldon deployment image reference
kubectl get seldondeployment iris -n argowf -o yaml | grep image:
```

### Solution Options

#### Option 1: Enable GHCR Push (Recommended)
Update your workflow to actually push images to GHCR:

```bash
# 1. Update your workflow.yaml to include registry credentials for Kaniko
# See the volumes section that needs to be added to the kaniko template

# 2. Apply the updated workflow
kubectl apply -f demo_iris_pipeline/workflow.yaml

# 3. Delete and restart the workflow
argo delete iris-demo -n argowf
argo submit demo_iris_pipeline/workflow.yaml -n argowf
```

#### Option 2: Use Public Test Image (Quick Fix)
Temporarily use a working public image:

```bash
# Patch the Seldon deployment to use a public test image
kubectl patch seldondeployment iris -n argowf --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/predictors/0/componentSpecs/0/spec/containers/0/image",
    "value": "seldonio/sklearn-iris:0.1"
  }
]'

# Wait for new pod to start
kubectl get pods -n argowf -l seldon-deployment-id=iris -w
```

#### Option 3: Manual Image Push
Build and push the image manually as a workaround:

```bash
# 1. Build the image locally using the exact same process
cd demo_iris_pipeline

# 2. Copy the model from the workflow output (if accessible)
# Or train locally: python train.py

# 3. Build with the same tag
docker build -t ghcr.io/jtayl222/iris:latest .

# 4. Push to GHCR (using your existing credentials)
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
docker push ghcr.io/jtayl222/iris:latest

# 5. Delete the failing pod to trigger a new pull
kubectl delete pod -n argowf -l seldon-deployment-id=iris --force --grace-period=0
```

### Permanent Fix: Update Workflow for Registry Push

Add this to your Kaniko template in `workflow.yaml`:

```yaml
# In the kaniko template, add these volume mounts and volumes:
volumeMounts:
- name: docker-config
  mountPath: /kaniko/.docker
  readOnly: true
# ... other volume mounts

volumes:
- name: docker-config
  secret:
    secretName: ghcr-secret
    items:
    - key: .dockerconfigjson
      path: config.json

# And add this environment variable:
env:
- name: DOCKER_CONFIG
  value: /kaniko/.docker
```

### Verification Steps

After applying any fix:

```bash
# 1. Check pod status
kubectl get pods -n argowf -l seldon-deployment-id=iris

# 2. If pod is running, test the endpoint
kubectl port-forward -n argowf svc/iris-default 8080:8000 &

# 3. Test prediction
curl -X POST http://localhost:8080/api/v1.0/predictions \
  -H "Content-Type: application/json" \
  -d '{"data": {"ndarray": [[5.1, 3.5, 1.4, 0.2]]}}'

# Expected response:
# {"data":{"names":["t:0","t:1","t:2"],"ndarray":[[0.0,0.0,1.0]]},"meta":{}}
```

### Understanding the Pattern

This is a common MLOps pattern where:
- **Build step succeeds** because it doesn't require network access
- **Deploy step succeeds** because it only creates Kubernetes manifests
- **Runtime fails** because the actual image pull happens when pods start

The fix requires ensuring that your build process actually publishes artifacts to the registry that your deployment references.