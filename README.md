# Homelab MLOps Demo

A complete MLOps pipeline demonstrating machine learning workflows using Argo Workflows, ArgoCD, and Kubernetes in a homelab environment.

## Overview

This project showcases:
- **ML Pipeline**: Iris classification model training and serving
- **GitOps**: Automated deployment using ArgoCD
- **Workflow Orchestration**: Argo Workflows for ML pipeline execution
- **Model Serving**: Containerized model deployment with Seldon Core

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

## Repository Structure

```
homelab-mlops-demo/
├── applications/                    # ArgoCD application configs
│   └── demo-iris-pipeline-app.yaml # Main application definition
├── demo_iris_pipeline/
│   └── src/                        # Python source code
│       ├── train.py               # ML training script
│       ├── serve.py               # Model serving endpoint
│       ├── Dockerfile             # Container definition
│       └── requirements.txt       # Dependencies
├── manifests/
│   ├── configmaps/                # Generated ConfigMaps
│   ├── workflows/                 # Workflow definitions
│   └── rbac/                      # RBAC configurations
└── scripts/
    ├── update-configmap.sh        # Update source ConfigMap
    └── apply-workflows.sh         # Deploy workflows
```

## Prerequisites

- **Kubernetes cluster** with K3s
- **ArgoCD** in `argocd` namespace
- **Argo Workflows** in `argowf` namespace
- **Seldon Core** operator
- **MinIO** for model storage
- **MLflow** for experiment tracking
- **NFS storage class** (`nfs-shared`)

## Quick Start

### 1. Deploy the Application
```bash
# Apply RBAC
kubectl apply -f manifests/rbac/

# Create ArgoCD application
kubectl apply -f applications/demo-iris-pipeline-app.yaml

# Generate source code ConfigMap
./scripts/update-configmap.sh argowf

# Deploy workflows
./scripts/apply-workflows.sh argowf
```

### 2. Run the Pipeline
```bash
# Submit workflow
argo submit manifests/workflows/iris-workflow.yaml -n argowf --watch

# Monitor progress
argo list -n argowf
argo logs iris-demo -n argowf
```

### 3. Access Services
- **Argo Workflows UI**: `http://<cluster-ip>:2746`
- **ArgoCD UI**: Check deployment status
- **MLflow UI**: View experiment tracking

## Pipeline Steps

1. **Train**: Train RandomForest model on Iris dataset, log to MLflow
2. **Build**: Create container image with trained model using Kaniko
3. **Deploy**: Deploy model serving endpoint with Seldon Core

## Development Workflow

### Making Changes
```bash
# 1. Modify source files in demo_iris_pipeline/src/
# 2. Update ConfigMap
./scripts/update-configmap.sh argowf

# 3. Apply changes (if workflow definitions changed)
./scripts/apply-workflows.sh argowf

# 4. Run pipeline
argo submit manifests/workflows/iris-workflow.yaml -n argowf --watch
```

### Testing Model Endpoint
```bash
# Port forward to model service
kubectl port-forward -n argowf svc/iris-default 8080:8000

# Test prediction
curl -X POST http://localhost:8080/api/v1.0/predictions \
  -H "Content-Type: application/json" \
  -d '{"data": {"ndarray": [[5.1, 3.5, 1.4, 0.2]]}}'
```

## Common Commands

```bash
# Workflow management
argo list -n argowf
argo delete iris-demo -n argowf
argo logs iris-demo -n argowf

# ArgoCD management
argocd app list
argocd app sync homelab-mlops-demo

# Debugging
kubectl get pods -n argowf
kubectl describe pod <pod-name> -n argowf
```

## Troubleshooting

### Workflow Already Exists
```bash
argo delete iris-demo -n argowf
argo submit manifests/workflows/iris-workflow.yaml -n argowf --watch
```

### ConfigMap Issues
```bash
# Regenerate ConfigMap after source changes
./scripts/update-configmap.sh argowf
```

### Registry Authentication (for private repos)
```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<username> \
  --docker-password=<token> \
  --docker-email=<email> \
  -n argowf
```

### Complete Reset
```bash
# Delete everything and start fresh
argo delete -n argowf --all
kubectl delete seldondeployment --all -n argowf
argocd app delete homelab-mlops-demo --cascade
kubectl apply -f applications/demo-iris-pipeline-app.yaml
```

## Model Serving

The deployed model provides a REST API:

```bash
# Prediction request
curl -X POST http://<endpoint>/api/v1.0/predictions \
  -H "Content-Type: application/json" \
  -d '{"data": {"ndarray": [[5.1, 3.5, 1.4, 0.2]]}}'

# Response
{"data": {"names": ["class:0", "class:1", "class:2"], "ndarray": [[0.9, 0.05, 0.05]]}}
```