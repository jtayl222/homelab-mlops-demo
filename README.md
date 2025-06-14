# Homelab MLOps Demo

A complete MLOps pipeline demonstrating machine learning workflows using Argo Workflows, ArgoCD, and Kubernetes in a homelab environment with **GitOps** and **kustomize-based configuration management**.

## Overview

This project showcases:
- **ML Pipeline**: Iris classification model training and serving
- **GitOps**: Automated deployment using ArgoCD with kustomize overlays
- **Workflow Orchestration**: Argo Workflows for ML pipeline execution
- **Model Serving**: Containerized model deployment with Seldon Core
- **Configuration Management**: Centralized port and environment configuration with kustomize

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
│   ├── base/                      # Base kustomize configuration
│   │   ├── configmaps/           # ConfigMaps including app-config
│   │   ├── workflows/            # Workflow definitions
│   │   ├── rbac/                 # RBAC configurations
│   │   ├── secrets/              # Secret templates
│   │   └── patches/              # Configuration patches
│   └── overlays/                  # Environment-specific overlays
│       ├── development/          # Development environment config
│       └── production/           # Production environment config
├── scripts/                       # Automation scripts
├── makefile                       # Convenient build targets
└── dev-environment/               # Development workflow docs
```

## Prerequisites

- **Kubernetes cluster** with K3s
- **ArgoCD** in `argocd` namespace
- **Argo Workflows** in `argowf` namespace
- **Seldon Core** operator
- **MinIO** for model storage
- **MLflow** for experiment tracking
- **NFS storage class** (`nfs-shared`)
- **GitHub Personal Access Token** for private container registry

## Quick Start

### 1. Set Environment Variables
```bash
export GITHUB_USERNAME='your-github-username'
export GITHUB_TOKEN='ghp_your_token_here'
export GITHUB_EMAIL='your-email@example.com'
```

### 2. Deploy with Kustomize (Recommended)
```bash
# Deploy to production environment
make deploy-prod

# Or deploy to development environment
make deploy-dev

# Run the ML pipeline
make demo-prod    # Production
make demo-dev     # Development
```

### 3. Alternative: Manual Deployment
```bash
# Deploy production environment with kustomize
kubectl apply -k manifests/overlays/production

# Deploy development environment with kustomize
kubectl apply -k manifests/overlays/development

# Submit workflow manually
argo submit manifests/base/workflows/iris-workflow.yaml -n argowf --watch
```

## Configuration Management

### Centralized Configuration
All port and environment configurations are managed through kustomize:

```yaml
# manifests/base/configmaps/app-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  MODEL_SERVING_PORT: "9000"      # Production default
  MODEL_METRICS_PORT: "6000"
  MINIO_PORT: "9000"
  MINIO_HOST: "minio.minio.svc.cluster.local"
```

### Environment-Specific Overrides
```yaml
# manifests/overlays/development/app-config-patch.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  MODEL_SERVING_PORT: "9001"      # Development override
```

### Configuration Commands
```bash
# View current configuration
make show-config

# Validate configuration
make validate-kustomize

# Preview what will be deployed
make preview-dev      # Development environment
make preview-prod     # Production environment

# Check for remaining hardcoded ports
make clean-ports
```

## Pipeline Steps

1. **Train**: Train RandomForest model on Iris dataset, log to MLflow
2. **Build**: Create container image with trained model using Kaniko
3. **Deploy**: Deploy model serving endpoint with Seldon Core

## Development Workflow

### Making Changes
```bash
# 1. Create feature branch
git checkout -b feature/your-feature

# 2. Make changes to source files
# Edit demo_iris_pipeline/src/*, manifests/*, etc.

# 3. Deploy to development environment
make deploy-dev

# 4. Test changes
make demo-dev
make smoke-test-dev

# 5. Merge when ready
git checkout main && git merge feature/your-feature
```

### Testing Model Endpoint
```bash
# Get dynamic port configuration
DEV_PORT=$(make show-config | grep "Development port" | cut -d: -f2 | tr -d ' ')
PROD_PORT=$(make show-config | grep "Production port" | cut -d: -f2 | tr -d ' ')

# Port forward with correct port
make port-forward-dev   # Development
make port-forward-prod  # Production

# Or manually with dynamic port
kubectl port-forward -n argowf-dev svc/dev-iris-0-2-0-default-classifier $DEV_PORT:$DEV_PORT &
kubectl port-forward -n argowf svc/iris-0-2-0-default-classifier $PROD_PORT:$PROD_PORT &

# Test prediction with dynamic port
curl -X POST http://localhost:$DEV_PORT/api/v1.0/predictions \
  -H "Content-Type: application/json" \
  -d '{"data": {"ndarray": [[5.1, 3.5, 1.4, 0.2]]}}'
```

## Available Make Targets

```bash
# Configuration management
make show-config         # Show current port configuration
make validate-kustomize  # Validate all kustomizations
make preview-dev        # Preview development manifests
make preview-prod       # Preview production manifests
make clean-ports        # Check for hardcoded ports

# Environment management
make deploy-dev         # Deploy development environment
make deploy-prod        # Deploy production environment
make demo-dev          # Run development demo
make demo-prod         # Run production demo

# Testing and debugging
make smoke-test-dev     # Test development deployment
make smoke-test-prod    # Test production deployment
make port-forward-dev   # Port forward development service
make port-forward-prod  # Port forward production service
make workflow-status    # Check workflow status
make cleanup           # Clean up all environments

# Help
make help              # Show all available targets
```

## Common Commands

```bash
# Workflow management
argo list -n argowf
argo list -n argowf-dev
argo delete iris-demo -n argowf
argo logs iris-demo -n argowf

# ArgoCD management
argocd app list
argocd app sync homelab-mlops-demo

# Kustomize management
kubectl kustomize manifests/overlays/development
kubectl kustomize manifests/overlays/production
kubectl apply -k manifests/overlays/development

# Debugging
kubectl get pods -n argowf
kubectl get pods -n argowf-dev
kubectl describe pod <pod-name> -n argowf
```

## Troubleshooting

### Configuration Issues
```bash
# Check current configuration
make show-config

# Validate kustomize configuration
make validate-kustomize

# Check for remaining hardcoded references
make clean-ports

# Preview configuration before applying
make preview-dev
make preview-prod
```

### Workflow Issues
```bash
# Check workflow status
make workflow-status

# Restart workflow
argo delete iris-demo -n argowf
make demo-prod
```

### Port Configuration Issues
```bash
# Verify port assignments
kubectl get configmap -n argowf app-config -o yaml
kubectl get configmap -n argowf-dev dev-app-config -o yaml

# Test connectivity with correct ports
make smoke-test-dev
make smoke-test-prod
```

### Environment Setup Issues
```bash
# Clean and restart development environment
./scripts/restart-demo.sh argowf-dev restart

# Clean and restart production environment  
./scripts/restart-demo.sh argowf restart

# Check environment variables
echo "GITHUB_USERNAME: $GITHUB_USERNAME"
echo "GITHUB_TOKEN: ${GITHUB_TOKEN:0:7}..."
echo "GITHUB_EMAIL: $GITHUB_EMAIL"
```

### Registry Authentication
```bash
# Create registry secret (handled automatically by restart script)
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USERNAME \
  --docker-password=$GITHUB_TOKEN \
  --docker-email=$GITHUB_EMAIL \
  -n argowf
```

### Complete Reset
```bash
# Clean up everything
make cleanup

# Reset ArgoCD applications
argocd app delete homelab-mlops-demo --cascade

# Redeploy from scratch
make deploy-prod
make demo-prod
```

## Model Serving

The deployed model provides a REST API with dynamic port configuration:

```bash
# Get current port configuration
PROD_PORT=$(./scripts/get-config.sh production)
DEV_PORT=$(./scripts/get-config.sh development)

# Production prediction request
curl -X POST http://localhost:$PROD_PORT/api/v1.0/predictions \
  -H "Content-Type: application/json" \
  -d '{"data": {"ndarray": [[5.1, 3.5, 1.4, 0.2]]}}'

# Development prediction request
curl -X POST http://localhost:$DEV_PORT/api/v1.0/predictions \
  -H "Content-Type: application/json" \
  -d '{"data": {"ndarray": [[5.1, 3.5, 1.4, 0.2]]}}'

# Expected response
{"data": {"names": ["class:0", "class:1", "class:2"], "ndarray": [[0.9, 0.05, 0.05]]}}
```

## Environment Comparison

| Feature | Development | Production |
|---------|-------------|------------|
| Namespace | `argowf-dev` | `argowf` |
| Name Prefix | `dev-` | None |
| Model Port | `9001` (default) | `9000` (default) |
| Resource Limits | Lower | Higher |
| ArgoCD App | `homelab-mlops-demo-dev` | `homelab-mlops-demo` |
| Kustomize Overlay | `development` | `production` |

## Advanced Usage

### Custom Port Configuration
```bash
# Edit port configuration
nano manifests/base/configmaps/app-config.yaml

# Or override in environment overlay
nano manifests/overlays/development/app-config-patch.yaml

# Validate and deploy
make validate-kustomize
make deploy-dev
```

### Multi-Environment Testing
```bash
# Deploy to both environments
make deploy-dev
make deploy-prod

# Test both environments
make smoke-test-dev
make smoke-test-prod

# Compare configurations
make show-config
```

### Development with Custom Namespace
```bash
# Deploy to custom development namespace
./scripts/restart-demo.sh argowf-dev-alice deploy

# Create custom overlay (advanced)
cp -r manifests/overlays/development manifests/overlays/custom
# Edit manifests/overlays/custom/app-config-patch.yaml
kubectl apply -k manifests/overlays/custom
```

## Documentation

- **[Development Workflow](dev-environment/docs/development-workflow.md)**: Detailed development guide
- **[Troubleshooting](dev-environment/docs/troubleshooting.md)**: Common issues and solutions
- **[Configuration Management](manifests/README.md)**: Kustomize configuration details

## Contributing

1. Fork the repository
2. Create a feature branch
3. Deploy to development environment: `make deploy-dev`
4. Test changes: `make demo-dev && make smoke-test-dev`
5. Validate configuration: `make validate-kustomize`
6. Submit pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.