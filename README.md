# Homelab MLOps Demo

A complete MLOps pipeline demonstrating machine learning workflows using Argo Workflows, ArgoCD, and Kubernetes in a homelab environment.

## Overview

This project showcases:
- **ML Pipeline**: Iris classification model training and serving
- **GitOps**: Automated deployment using ArgoCD
- **Workflow Orchestration**: Argo Workflows for ML pipeline execution
- **Model Serving**: Containerized model deployment with Seldon Core
- **Infrastructure as Code**: Kubernetes manifests and automation scripts

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Git Repo      │───▶│    ArgoCD       │───▶│ Argo Workflows  │
│   (GitOps)      │    │   (Deployment)  │    │ (ML Pipeline)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    MLflow       │    │     MinIO       │    │  Seldon Core    │
│  (Tracking)     │    │   (Storage)     │    │ (Model Serving) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Key Components Overview

### Core Files

#### demo-iris-pipeline-app.yaml
**Purpose**: ArgoCD Application definition for GitOps deployment  
**Function**: 
- Tells ArgoCD where to find the ML pipeline code (this repository)
- Configures automatic sync from Git to Kubernetes
- Deploys workflow and ConfigMap to the `argowf` namespace
- Enables GitOps: any changes pushed to Git are automatically deployed

```yaml
# Points ArgoCD to this repo and the demo_iris_pipeline/ directory
source:
  repoURL: https://github.com/jtayl222/homelab-mlops-demo.git
  path: demo_iris_pipeline
destination:
  namespace: argowf  # Where workflows run
```

#### workflow.yaml
**Purpose**: Argo Workflows pipeline definition  
**Function**:
- Defines the 3-step ML pipeline: Train → Build → Deploy
- Orchestrates containers, volumes, and dependencies
- Handles NFS permissions and environment setup
- References the ConfigMap for source code

```yaml
# Workflow steps
entrypoint: iris-pipeline
templates:
- name: train     # Train ML model
- name: build     # Build container image  
- name: deploy    # Deploy model endpoint
```

#### update-configmap.sh
**Purpose**: Generates Kubernetes ConfigMap from source files  
**Function**:
- Packages Python scripts, Dockerfile, and requirements into a ConfigMap
- Must be run whenever source code changes
- Creates `iris-src-configmap.yaml` with all application files
- Separates source code management from workflow orchestration

```bash
# Packages these files into a ConfigMap:
--from-file=train.py=demo_iris_pipeline/train.py
--from-file=serve.py=demo_iris_pipeline/serve.py  
--from-file=Dockerfile=demo_iris_pipeline/Dockerfile
--from-file=requirements.txt=demo_iris_pipeline/requirements.txt
```

### How They Work Together

1. **Developer Workflow**:
   - Modify `train.py` or other source files
   - Run update-configmap.sh to package changes
   - Commit and push to Git

2. **GitOps Deployment**: 
   - ArgoCD (via `demo-iris-pipeline-app.yaml`) detects Git changes
   - Automatically syncs `workflow.yaml` and `iris-src-configmap.yaml` to Kubernetes
   - Argo Workflows executes the pipeline using the updated source code

3. **Pipeline Execution**:
   - `workflow.yaml` orchestrates the ML pipeline steps
   - Each step mounts the ConfigMap to access source files
   - Model training, building, and deployment happen automatically

This design separates concerns: source code (ConfigMap), orchestration (Workflow), and deployment (ArgoCD Application).

---

This explanation should go right after the Architecture diagram and before the Repository Structure section, giving readers a clear understanding of how the key pieces fit together before diving into the details.

## Repository Structure

```
homelab-mlops-demo/
├── applications/                    # GitOps application configurations
│   ├── demo-iris-pipeline-app.yaml # ArgoCD application definition
│   ├── argowf-seldon-rbac.yaml    # RBAC for Seldon deployments
│   └── argocd-workflow-rbac.yaml  # RBAC for ArgoCD workflow management
├── demo_iris_pipeline/             # ML pipeline components
│   ├── workflow.yaml              # Argo Workflow definition
│   ├── iris-src-configmap.yaml    # Kubernetes ConfigMap for source files
│   ├── train.py                   # ML training script
│   ├── serve.py                   # Model serving endpoint
│   ├── Dockerfile                 # Container image definition
│   └── requirements.txt           # Python dependencies
├── update-configmap.sh            # Script to regenerate ConfigMaps
├── install_200_deploy_mlops_demo_app.yml # Ansible deployment playbook
└── README.md                      # This file
```

## Prerequisites

### Infrastructure Requirements
- **Kubernetes cluster** (K3s recommended for homelab)
- **ArgoCD** installed and configured in `argocd` namespace
- **Argo Workflows** installed and configured in `argowf` namespace  
- **Seldon Core** operator for model serving
- **Sealed Secrets** controller for secret management

### Storage & Tracking
- **MinIO**: S3-compatible storage for model artifacts
- **MLflow**: Experiment tracking and model registry
- **NFS Storage**: Shared storage class (`nfs-shared`) for workflow data

### Secrets Management
Sealed secrets and credentials are managed in the infrastructure repository.
Ensure the following secrets exist in the `argowf` namespace:
- `minio-credentials-wf`: MinIO access credentials
- `github-credentials`: (optional) For container image pushing

## Quick Start

### 1. Deploy Infrastructure Components
```bash
# Apply RBAC configurations
kubectl apply -f applications/argocd-workflow-rbac.yaml
kubectl apply -f applications/argowf-seldon-rbac.yaml
```

### 2. Deploy the MLOps Application
```bash
# Create the ArgoCD application
kubectl apply -f applications/demo-iris-pipeline-app.yaml
```

### 3. Generate and Apply ConfigMap
```bash
# Generate ConfigMap with source files
./update-configmap.sh

# Apply the ConfigMap
kubectl apply -f demo_iris_pipeline/iris-src-configmap.yaml
```

### 4. Run the ML Pipeline
```bash
# Submit workflow directly (for testing)
argo submit demo_iris_pipeline/workflow.yaml -n argowf --watch

# Or let ArgoCD manage it automatically via GitOps
argocd app sync homelab-mlops-demo
```

### 5. Access Services
- **ArgoCD UI**: Check deployment status and sync operations
- **Argo Workflows UI**: Monitor pipeline execution at `http://<cluster-ip>:2746`
- **MLflow UI**: View experiment tracking and model metrics
- **Model Endpoint**: REST API for model predictions

## Pipeline Workflow

The ML pipeline consists of three main steps:

### 1. Train Step
- **Container**: `jupyter/scipy-notebook:python-3.11`
- **Purpose**: Train machine learning model
- **Process**:
  - Fixes NFS permissions using security context (runs as root, then switches to jovyan)
  - Loads Iris dataset using scikit-learn
  - Trains RandomForest classifier
  - Logs metrics and parameters to MLflow
  - Saves trained model to shared NFS storage (`/output/model/model.pkl`)
- **Resources**: 2Gi memory, 1 CPU (requests), 4Gi memory, 2 CPU (limits)

### 2. Build Step (Kaniko)
- **Container**: `gcr.io/kaniko-project/executor:v1.23.0`
- **Purpose**: Build container image with trained model
- **Process**:
  - Copies trained model and application files to workspace
  - Builds Docker image using Kaniko (in-cluster builds)
  - Tags image as `ghcr.io/jtayl222/iris:latest`
  - Saves image tar for deployment step
- **Init Container**: Prepares workspace with model, Dockerfile, and serve.py

### 3. Deploy Step
- **Container**: `bitnami/kubectl:1.30`
- **Purpose**: Deploy model serving endpoint
- **Process**:
  - Creates Seldon deployment manifest
  - Deploys model serving REST API
  - Configures service endpoint for predictions
- **Result**: Running model inference service accessible via REST API

## Development Workflow

### Making Changes to the Pipeline

1. **Update Source Files**: Modify `train.py`, `serve.py`, or other components
2. **Regenerate ConfigMap**: 
   ```bash
   ./update-configmap.sh
   kubectl apply -f demo_iris_pipeline/iris-src-configmap.yaml
   ```
3. **Update Workflow**: Modify `workflow.yaml` if needed
4. **Commit & Push**: GitOps will automatically deploy changes
5. **Monitor**: Watch pipeline execution in Argo Workflows UI

### Testing Changes Before Commit

#### 1. Test Source Files Locally
```bash
# Test training script locally (requires MLflow setup)
export MLFLOW_TRACKING_URI=http://localhost:5000
export N_ESTIMATORS=50
python demo_iris_pipeline/train.py

# Test serving script (requires a trained model)
python demo_iris_pipeline/serve.py
```

#### 2. Test ConfigMap Generation
```bash
# Generate ConfigMap without applying
./update-configmap.sh

# Verify the ConfigMap looks correct
cat demo_iris_pipeline/iris-src-configmap.yaml | head -20

# Check for syntax errors
kubectl apply -f demo_iris_pipeline/iris-src-configmap.yaml --dry-run=client
```

#### 3. Test Workflow Validation
```bash
# Delete any existing test workflows first
argo -n argowf list
argo -n argowf delete iris-demo
# argo delete -n argowf --all

# Validate workflow syntax
argo lint demo_iris_pipeline/workflow.yaml

# Submit workflow directly (bypasses GitOps)
argo submit demo_iris_pipeline/workflow.yaml -n argowf --watch

# Check logs for debugging
argo -n argowf logs iris-demo

# Test individual steps if needed
argo submit demo_iris_pipeline/workflow.yaml -n argowf --entrypoint train --watch
```

#### 4. Test Container Build
```bash
# Build image locally to test Dockerfile
docker build -t iris-test demo_iris_pipeline/

# Test the serving container
docker run -p 8080:8080 iris-test
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [[5.1, 3.5, 1.4, 0.2]]}'
```

#### 5. Validate Kubernetes Manifests
```bash
# Dry-run all manifests
kubectl apply -f demo_iris_pipeline/ --dry-run=client
kubectl apply -f applications/ --dry-run=client

# Check YAML syntax
yamllint demo_iris_pipeline/workflow.yaml
```

#### 6. Pre-commit Validation Script
Create a `test-pipeline.sh` script for automated testing:

```bash
#!/bin/bash
# test-pipeline.sh

set -e

echo "🧪 Testing MLOps pipeline changes..."

# Test ConfigMap generation
echo "1. Testing ConfigMap generation..."
./update-configmap.sh
kubectl apply -f demo_iris_pipeline/iris-src-configmap.yaml --dry-run=client

# Validate workflow
echo "2. Validating workflow YAML..."
argo lint demo_iris_pipeline/workflow.yaml

# Test container build
echo "3. Testing container build..."
docker build -t iris-test demo_iris_pipeline/ > /dev/null

# Check Python syntax
echo "4. Checking Python syntax..."
python -m py_compile demo_iris_pipeline/train.py
python -m py_compile demo_iris_pipeline/serve.py

echo "✅ All tests passed! Ready to commit."
```

Run before committing:
```bash
chmod +x test-pipeline.sh
./test-pipeline.sh
```

#### 7. Integration Testing
```bash
# Submit full workflow and monitor
argo submit demo_iris_pipeline/workflow.yaml -n argowf --watch

# Check if all steps complete successfully
argo get -n argowf <workflow-name>

# Test model endpoint after deployment
kubectl port-forward -n argowf svc/iris 8080:8080 &
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [[5.1, 3.5, 1.4, 0.2]]}'
```

### Testing Locally
```bash
# Test individual components
python demo_iris_pipeline/train.py
python demo_iris_pipeline/serve.py

# Test full workflow
argo submit demo_iris_pipeline/workflow.yaml -n argowf --watch
```

### Common Issues

**Workflow Already Exists**:
```bash
# Delete existing workflow before resubmitting
argo delete <workflow-name> -n argowf

# Or delete all workflows
argo delete -n argowf --all

# Then resubmit
argo submit demo_iris_pipeline/workflow.yaml -n argowf --watch
```

**Permission Errors on NFS**:
- The workflow uses `securityContext` to run as root initially, then switches to jovyan user
- Ensures proper file permissions on shared NFS storage

**Command Not Found Errors**:
- Ensure conda environment is properly sourced when switching users
- Use full paths to conda binaries if environment sourcing fails

**ConfigMap Not Updating**:
- Run `./update-configmap.sh` after modifying source files
- Apply the generated ConfigMap with `kubectl apply`

**JSON Input Errors**:
- Usually occurs in build or deploy steps after successful training
- Check container registry authentication for Kaniko builds
- Verify Kubernetes API access for deployment steps
- Use `argo logs <workflow> | grep -i json` to locate the specific error

### ConfigMap Management
The `update-configmap.sh` script generates a Kubernetes ConfigMap containing:
- `train.py`: Machine learning training script
- `serve.py`: FastAPI model serving application  
- `Dockerfile`: Container image definition
- `requirements.txt`: Python package dependencies

```bash
# Regenerate ConfigMap after source changes
./update-configmap.sh
kubectl apply -f demo_iris_pipeline/iris-src-configmap.yaml
```

## Model Serving

The deployed model provides a REST API endpoint:

```bash
# Example prediction request
curl -X POST http://<model-endpoint>/predict \
  -H "Content-Type: application/json" \
  -d '{
    "instances": [[5.1, 3.5, 1.4, 0.2]]
  }'

# Response
{
  "predictions": [0]
}
```

## Troubleshooting

### Common Issues

**Workflow Already Exists**:
```bash
# Delete existing workflow before resubmitting
argo delete <workflow-name> -n argowf

# Or delete all workflows
argo delete -n argowf --all

# Then resubmit
argo submit demo_iris_pipeline/workflow.yaml -n argowf --watch
```

**ArgoCD Application Issues**:
```bash
# List ArgoCD applications
argocd app list

# Delete ArgoCD application (keeps resources)
argocd app delete homelab-mlops-demo

# Delete ArgoCD application and all resources (cascade delete)
argocd app delete homelab-mlops-demo --cascade

# Force delete if stuck with finalizers
kubectl patch app homelab-mlops-demo -n argocd -p '{"metadata":{"finalizers":[]}}' --type=merge

# Recreate application
kubectl apply -f applications/demo-iris-pipeline-app.yaml
```

**Permission Errors on NFS**:
- The workflow uses `securityContext` to run as root initially, then switches to jovyan user
- Ensures proper file permissions on shared NFS storage

**Command Not Found Errors**:
- Ensure conda environment is properly sourced when switching users
- Use full paths to conda binaries if environment sourcing fails

**ConfigMap Not Updating**:
- Run `./update-configmap.sh` after modifying source files
- Apply the generated ConfigMap with `kubectl apply`

**JSON Input Errors**:
- Usually occurs in build or deploy steps after successful training
- Check container registry authentication for Kaniko builds
- Verify Kubernetes API access for deployment steps
- Use `argo logs <workflow> | grep -i json` to locate the specific error

## Useful Commands

### Workflow Management
```bash
argo list -n argowf                    # List workflows
argo logs -n argowf <workflow-name>    # View workflow logs
argo delete -n argowf <workflow-name>  # Delete workflow
argo get -n argowf <workflow-name>     # Get workflow details
argo submit demo_iris_pipeline/workflow.yaml -n argowf --watch  # Submit workflow
```

### ArgoCD Management  
```bash
argocd app list                        # List applications
argocd app get homelab-mlops-demo      # Get app details
argocd app sync homelab-mlops-demo     # Sync application
argocd app delete homelab-mlops-demo   # Delete application (keep resources)
argocd app delete homelab-mlops-demo --cascade  # Delete app and resources
argocd app history homelab-mlops-demo  # View sync history
argocd app rollback homelab-mlops-demo # Rollback to previous version
```

### Kubernetes Debugging
```bash
kubectl get pods -n argowf             # List pods
kubectl describe pod -n argowf <pod>   # Pod details
kubectl logs -n argowf <pod>           # Pod logs
kubectl get configmap iris-src -n argowf -o yaml  # View ConfigMap
kubectl get secrets -n argowf          # List secrets
```

## Complete Cleanup

### Remove Everything
```bash
# Delete ArgoCD application and all resources
argocd app delete homelab-mlops-demo --cascade

# Clean up any remaining workflows
argo delete -n argowf --all

# Remove ConfigMap
kubectl delete configmap iris-src -n argowf

# Clean up old persistent volumes (optional)
kubectl get pv | grep "Released.*iris-demo-workdir" | awk '{print $1}' | xargs kubectl delete pv
```

### Reset and Redeploy
```bash
# Recreate from scratch
kubectl apply -f applications/demo-iris-pipeline-app.yaml
argocd app sync homelab-mlops-demo

# Or use the Ansible playbook
ansible-playbook install_200_deploy_mlops_demo_app.yml
```

## Monitoring & Observability

- **Pipeline Status**: Argo Workflows UI shows real-time execution progress
- **Model Metrics**: MLflow tracks model accuracy, parameters, and artifacts
- **Resource Usage**: Monitor via Kubernetes metrics and Prometheus/Grafana
- **Logs**: Centralized logging for debugging workflow issues

## Debugging ArgoCD Manifests

### Understanding What ArgoCD Deploys

ArgoCD can sometimes deploy different versions than what you expect. Use these commands to debug:

#### Check What ArgoCD Will Deploy
```bash
# View the exact manifests ArgoCD will apply
argocd app manifests homelab-mlops-demo

# Check specific parts of the workflow
argocd app manifests homelab-mlops-demo | grep -A 30 "securityContext"
argocd app manifests homelab-mlops-demo | grep -A 20 "train"
```

#### Compare Local vs ArgoCD Manifests
```bash
# View your local workflow
cat demo_iris_pipeline/workflow.yaml | grep -A 10 "securityContext"

# Compare with what ArgoCD sees
argocd app manifests homelab-mlops-demo | grep -A 10 "securityContext"
```

### Common Manifest Issues

**ArgoCD Deploying Old Workflow Version**:
- Check if the workflow is embedded in multiple files
- Ensure ArgoCD Application points to the correct Git path
- Verify no old ConfigMaps contain workflow definitions

**ConfigMap vs Workflow Confusion**:
```bash
# Workflow should be read directly from workflow.yaml
argocd app manifests homelab-mlops-demo | grep -A 5 "kind: Workflow"

# ConfigMap should only contain application files (train.py, serve.py, etc.)
kubectl get configmap iris-src -n argowf -o yaml | grep -A 5 "data:"
```

**Security Context Missing**:
```bash
# Check if security context exists in ArgoCD's version
argocd app manifests homelab-mlops-demo | grep -A 5 "securityContext"

# If missing, check Git sync status
argocd app sync homelab-mlops-demo --force
```

### Troubleshooting Workflow Recreation

**When `argo delete` workflows get recreated by ArgoCD**:

1. **Check if ArgoCD manages the workflow**:
   ```bash
   kubectl get workflow iris-demo -n argowf -o yaml | grep -A 5 "ownerReferences"
   ```

2. **Temporarily disable ArgoCD sync**:
   ```bash
   argocd app set homelab-mlops-demo --sync-policy none
   argo delete -n argowf --all
   # Make your changes, then re-enable
   argocd app set homelab-mlops-demo --sync-policy automated
   ```

3. **Force ArgoCD to use latest Git version**:
   ```bash
   argocd app sync homelab-mlops-demo --force --prune
   ```

### Verifying the Fix

After making changes, verify ArgoCD deploys the correct version:

```bash
# 1. Check the manifest has your security context
argocd app manifests homelab-mlops-demo | grep -A 15 "securityContext"

# 2. Should show:
#    securityContext:
#      runAsUser: 0
#      runAsGroup: 0

# 3. Check the args contain permission fixes
argocd app manifests homelab-mlops-demo | grep -A 10 "chown -R 1000:100"
```

### Understanding ArgoCD Application Structure

```yaml
# applications/demo-iris-pipeline-app.yaml (CORRECT)
spec:
  source:
    repoURL: https://github.com/jtayl222/homelab-mlops-demo.git
    path: demo_iris_pipeline  # Points to directory containing workflow.yaml
    
# workflow.yaml should NOT contain an ArgoCD Application
# It should only contain the Workflow resource
```