# Exploring a Successful MLOps Deployment

This document shows how to explore and understand a successful MLOps deployment using ArgoCD and Argo Workflows. Use these commands and techniques to verify deployment status, understand the system state, and demonstrate your working pipeline to potential employers.

## Quick Success Verification

**The most important command to show your working pipeline:**

```bash
argo get iris-demo -n argowf
```

**What a successful pipeline looks like:**
```
Name:                iris-demo
Namespace:           argowf
ServiceAccount:      unset (will run with the default ServiceAccount)
Status:              Succeeded
Conditions:          
 PodRunning          False
 Completed           True
Created:             Tue Jun 10 12:11:34 -0400 (31 minutes ago)
Started:             Tue Jun 10 12:11:34 -0400 (31 minutes ago)
Finished:            Tue Jun 10 12:13:47 -0400 (29 minutes ago)
Duration:            2 minutes 13 seconds
Progress:            3/3
ResourcesDuration:   1m40s*(1 cpu),33m4s*(100Mi memory)

STEP              TEMPLATE       PODNAME                      DURATION  MESSAGE
 ✔ iris-demo      iris-pipeline                                           
 ├─✔ train        train          iris-demo-train-1086554222   31s         
 ├─✔ build-image  kaniko         iris-demo-kaniko-2925953904  1m          
 └─✔ deploy       deploy         iris-demo-deploy-2552441111  4s          
```

**Key success indicators:**
- ✅ **Status: Succeeded** - Pipeline completed successfully
- ✅ **Progress: 3/3** - All steps (train → build → deploy) finished  
- ✅ **Duration: ~2 minutes** - Fast end-to-end execution
- ✅ **All steps show ✔** - No failures in any stage

This single command demonstrates a complete, working MLOps pipeline that trains a model, builds a container image, and deploys it as a service.

**For detailed exploration of each component, see:**
- [Section 4: Pipeline Execution Status](#4-pipeline-execution-status) - Deep dive into workflow analysis
- [Section 1: ArgoCD Application Status](#1-argocd-application-status) - GitOps deployment verification
- [Section 5: Model Deployment Verification](#5-model-deployment-verification) - Testing the deployed model

---

## 1. ArgoCD Application Status

### Basic Application Information
```bash
# View high-level application status
argocd app list
```
**What to look for:**
- `STATUS: Synced` - Git repository matches cluster state
- `HEALTH: Healthy` - All resources are running correctly
- `SYNCPOLICY: Auto-Prune` - Automatic deployment and cleanup enabled

### Detailed Application Status
```bash
# Get comprehensive application details
argocd app get argocd/homelab-mlops-demo
```
**Key sections to examine:**

**Sync Status:**
```yaml
Sync Status:     Synced
Health Status:   Healthy
```

**Resource Health:**
```yaml
GROUP               KIND        NAMESPACE  NAME      STATUS  HEALTH   HOOK  MESSAGE
                    ConfigMap   argowf     iris-src  Synced  Healthy        configmap/iris-src unchanged
argoproj.io         Workflow    argowf     iris-demo  Synced  Healthy        workflow.argoproj.io/iris-demo configured
```
- All resources should show `STATUS: Synced` and `HEALTH: Healthy`
- The `Workflow` resource indicates your ML pipeline definition is deployed
- The `ConfigMap` contains your source code (train.py, serve.py, etc.)

**Recent Operations:**
```yaml
Operation:          Sync
Sync Revision:      abc123def (latest commit SHA)
Phase:              Succeeded
Message:            successfully synced (all tasks run)
```

### View Deployment History
```bash
# See sync history and changes over time
argocd app history argocd/homelab-mlops-demo
```
**Example output:**
```
ID  DATE                           REVISION
10  2025-06-10 15:30:45 -0400 EDT  abc123def (HEAD -> main)
9   2025-06-10 14:15:22 -0400 EDT  def456abc 
8   2025-06-10 13:45:10 -0400 EDT  ghi789def
```
This shows each deployment, when it happened, and which Git commit was deployed.

## 2. Examining Deployed Resources

### View Managed Kubernetes Resources

**Note:** ArgoCD manages resources differently than direct kubectl deployments. The workflow itself is managed by ArgoCD, but individual workflow runs create their own temporary resources.

```bash
# Check if ArgoCD-managed resources exist
kubectl get workflows -n argowf
kubectl get configmaps -n argowf

# Configmap details
kubectl get configmaps iris-src -n argowf -o yaml
kubectl get workflow iris-demo -n argowf -o yaml
```

**Example output:**
```bash
$ kubectl get workflows -n argowf
NAME        STATUS      AGE   MESSAGE
iris-demo   Succeeded   5m    

$ kubectl get configmaps iris-src -n argowf
NAME       DATA   AGE
iris-src   4      10m
```

### Inspect the Workflow Definition
```bash
# View the deployed workflow specification
kubectl get workflow iris-demo -n argowf -o yaml
```
**Key sections:**
- `spec.templates`: Defines your ML pipeline steps (train, build, deploy)
- `status.phase`: Should be `Succeeded` for a completed pipeline
- `status.nodes`: Shows status of each pipeline step

## 3. ArgoCD Manifest Verification

### View Exact Deployed Manifests
```bash
# See exactly what ArgoCD deployed from your Git repository
argocd app manifests argocd/homelab-mlops-demo
```
This command shows the rendered Kubernetes YAML that ArgoCD applied to your cluster. Use it to:
- Verify your local changes are actually deployed
- Debug configuration issues
- Understand how ArgoCD processes your files

### Compare Local vs Deployed
```bash
# Compare your local workflow with what's deployed
echo "=== LOCAL VERSION ==="
cat demo_iris_pipeline/workflow.yaml | grep -A 10 "securityContext"

echo "=== DEPLOYED VERSION ==="
argocd app manifests argocd/homelab-mlops-demo | grep -A 10 "securityContext"
```

### Examine ConfigMap Contents
```bash
# View the source code ConfigMap that ArgoCD deployed
argocd app manifests argocd/homelab-mlops-demo | grep -A 20 "kind: ConfigMap" -B 5

# Or check directly in cluster
kubectl get configmap iris-src -n argowf -o yaml
```
You should see your `train.py`, `serve.py`, `Dockerfile`, and `requirements.txt` embedded in the ConfigMap data.

## 4. Pipeline Execution Status

### Check Workflow Execution
```bash
# List recent workflow runs
argo list -n argowf

# Get detailed workflow status
argo get iris-demo -n argowf

# View workflow execution tree
argo get iris-demo -n argowf -o wide
```

**Successful pipeline output:**
```
Name:                iris-demo
Namespace:           argowf
ServiceAccount:      unset
Status:              Succeeded
Conditions:          
 PodRunning          False
 Completed           True
Created:             Mon Jun 10 15:30:00 -0400 (6 minutes ago)
Started:             Mon Jun 10 15:30:00 -0400 (6 minutes ago)
Finished:            Mon Jun 10 15:33:15 -0400 (3 minutes ago)
Duration:            3 minutes 15 seconds
Progress:            3/3

STEP              TEMPLATE       PODNAME                      DURATION  MESSAGE
 ✔ iris-demo      iris-pipeline                                         
 ├─✔ train        train          iris-demo-train-1234567890   45s       
 ├─✔ build-image  kaniko         iris-demo-kaniko-2345678901  1m20s     
 └─✔ deploy       deploy         iris-demo-deploy-3456789012  10s       
```

**Key indicators of success:**
- `Status: Succeeded`
- `Progress: 3/3` (all steps completed)
- All steps show `✔` (checkmark)
- No error messages in the MESSAGE column

### View Pipeline Logs
```bash
# View logs for the entire workflow
argo logs iris-demo -n argowf

# View logs for specific steps
argo logs iris-demo -n argowf --container train
argo logs iris-demo -n argowf --container kaniko  
argo logs iris-demo -n argowf --container deploy
```

## 5. Model Deployment Verification

### Check Seldon Deployment
```bash
# Check if model serving endpoint was deployed
kubectl get seldondeployments -n argowf

# Get detailed status
kubectl describe seldondeployment iris-0-2-0 -n argowf

# Check if pods are running
kubectl get pods -n argowf -l seldon-deployment-id=iris-0-2-0
```

**Successful deployment indicators:**
```bash
$ kubectl get seldondeployments -n argowf
NAME         AGE   READY
iris-0-2-0   5m    True

$ kubectl get pods -n argowf -l seldon-deployment-id=iris-0-2-0
NAME                                          READY   STATUS    RESTARTS   AGE
iris-0-2-0-default-0-classifier-xyz123       2/2     Running   0          5m
```

### Test Model Endpoint
```bash
# Port forward to test locally
kubectl port-forward -n argowf svc/iris-0-2-0-default-classifier 9000:9000 &

# Send test prediction request
curl -X POST http://localhost:9000/api/v1.0/predictions \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "ndarray": [[5.1, 3.5, 1.4, 0.2]]
    }
  }'

# Expected response
{
  "data": {
    "names": ["t:0"],
    "ndarray": [0]
  },
  "meta": {
    "requestPath": {
      "classifier": "ghcr.io/jtayl222/iris:v0.2.0"
    }
  }
}
```

### Model Deployment Details
```bash
# Check deployment annotations (your pipeline metadata)
kubectl get seldondeployment iris-0-2-0 -n argowf -o yaml | grep -A 10 annotations

# Shows:
# model.accuracy: "1.0"
# model.version: "0.2.0" 
# validation.status: "PASSED"
# deployment.timestamp: "2025-06-12T12:26:58.864009Z"
```

## 6. Storage and Artifacts

### Check MLflow Tracking
```bash
# If MLflow is accessible, check experiment tracking
kubectl port-forward -n mlflow svc/mlflow 5000:5000 &
```
Then visit `http://localhost:5000` to see:
- Experiment runs with logged parameters
- Model accuracy metrics
- Saved model artifacts

### Verify Persistent Storage
```bash
# Check persistent volumes created by workflow
kubectl get pv | grep iris-demo

# Check volume claims
kubectl get pvc -n argowf

# Examine NFS storage usage
kubectl get pvc -n argowf -o wide
```

## 7. GitOps Verification

### Confirm GitOps Workflow
```bash
# Check that changes to Git trigger deployments
echo "# Test comment" >> demo_iris_pipeline/workflow.yaml
git add demo_iris_pipeline/workflow.yaml
git commit -m "Test GitOps deployment"
git push origin main

# Watch ArgoCD detect and sync the change
argocd app get argocd/homelab-mlops-demo --watch

# Verify new revision is deployed
argocd app history argocd/homelab-mlops-demo | head -3
```

### Monitor Auto-Sync
```bash
# Watch for automatic synchronization
watch "argocd app get argocd/homelab-mlops-demo | grep -E 'Sync Status|Health Status|Revision'"
```

## 8. Demonstrating Your MLOps Pipeline

### Create a Demo Script
```bash
# Create demo.sh for showing the complete workflow
cat > demo.sh << 'EOF'
#!/bin/bash
echo "=== MLOps Pipeline Demo ==="

echo "1. Checking ArgoCD Application Status..."
argocd app get argocd/homelab-mlops-demo | grep -E "Status|Health"

echo -e "\n2. Viewing Pipeline Execution..."
argo get iris-demo -n argowf | grep -E "Status|Progress|STEP"

echo -e "\n3. Checking Model Deployment..."
kubectl get seldondeployments -n argowf

echo -e "\n4. Testing Model Endpoint..."
kubectl port-forward -n argowf svc/iris-default 9000:9000 &
sleep 2
curl -s -X POST http://localhost:9000/api/v1.0/predictions \
  -H "Content-Type: application/json" \
  -d '{"data": {"ndarray": [[5.1, 3.5, 1.4, 0.2]]}}' | jq .
kill %1

echo -e "\n5. GitOps Configuration..."
echo "Repository: $(argocd app get argocd/homelab-mlops-demo | grep 'Repo:' | awk '{print $2}')"
echo "Path: $(argocd app get argocd/homelab-mlops-demo | grep 'Path:' | awk '{print $2}')"
echo "Sync Policy: Auto-Prune (GitOps enabled)"

echo -e "\n=== Demo Complete ==="
EOF

chmod +x demo.sh
./demo.sh
```

### Document Your Achievement

**For your README.md, add:**
```markdown
## Live Demo Results

✅ **GitOps Deployment**: ArgoCD automatically deploys from Git repository  
✅ **ML Pipeline**: 3-step workflow (Train → Build → Deploy) executes successfully  
✅ **Model Serving**: REST API endpoint serves predictions  
✅ **Artifact Storage**: Models and metrics stored in MinIO/MLflow  
✅ **Container Building**: Kaniko builds images without Docker daemon  
✅ **Kubernetes Native**: All components run on Kubernetes  

### Pipeline Metrics
- **Execution Time**: ~3 minutes end-to-end
- **Model Accuracy**: 95%+ on Iris dataset
- **Resource Usage**: 2Gi memory, 1 CPU per step
- **Storage**: 1Gi NFS persistent volume
```

## 9. Key Talking Points for Interviews

When discussing this project with potential employers, highlight:

### Technical Architecture
- **"I implemented a complete GitOps workflow using ArgoCD for automated ML pipeline deployment"**
- **"The system uses Argo Workflows to orchestrate training, building, and deployment in Kubernetes"**
- **"All components are containerized and use Kubernetes-native tools like Kaniko for in-cluster builds"**

### Problem-Solving Skills
- **"I debugged a complex version mismatch between Argo controller and executor components"**
- **"Implemented proper NFS permission handling using security contexts and user switching"**
- **"Set up artifact storage with MinIO and experiment tracking with MLflow"**

### MLOps Best Practices
- **"Source code is managed in ConfigMaps, separating application code from infrastructure"**
- **"The pipeline includes proper artifact management and model versioning"**
- **"GitOps ensures reproducible deployments and change tracking"**

### Demonstrable Results
- **"I can show you the live pipeline running end-to-end in about 3 minutes"**
- **"The model endpoint accepts REST API calls and returns predictions"**
- **"All changes are automatically deployed when pushed to Git"**

Use the commands in this document to provide concrete evidence during technical discussions or live demos.