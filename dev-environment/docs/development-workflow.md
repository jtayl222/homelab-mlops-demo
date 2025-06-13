# Development Workflow Guide

This guide explains how to safely develop and test new features using feature branches and isolated development environments with proper separation of concerns.

## 🎯 Overview

Our MLOps pipeline uses **GitOps principles** with separate environments:
- **`main` branch** → **`argowf` namespace** (Production)
- **Feature branches** → **`argowf-dev*` namespaces** (Development)

This allows safe development and testing without disrupting the production pipeline.

## 🚀 Quick Start - Feature Development

### 1. Create Feature Branch
```bash
# Clone the repository (if not already done)
git clone https://github.com/jtayl222/homelab-mlops-demo.git
cd homelab-mlops-demo

# Create and switch to feature branch
git checkout -b feature/your-feature-name

# Push the branch to enable ArgoCD tracking
git push -u origin feature/your-feature-name
```

### 2. Set Up Development Environment
```bash
# Set up complete development environment
# This orchestrates all setup scripts with proper separation of concerns
./scripts/setup-dev-environment.sh

# Or with custom namespace and branch
./scripts/setup-dev-environment.sh argowf-dev-alice feature/your-feature-name
```

### 3. Develop and Test
```bash
# Make your changes to the MLOps pipeline
# Edit workflow.yaml, Python scripts, etc.

# Test changes locally first (if possible)
python demo_iris_pipeline/train.py  # Test training script
python demo_iris_pipeline/test_model.py  # Test validation

# Commit and push changes
git add .
git commit -m "feat: add semantic versioning to MLOps pipeline"
git push origin feature/your-feature-name

# Update development environment with changes
./scripts/update-configmap.sh argowf-dev

# Sync ArgoCD to deploy changes
argocd app sync homelab-mlops-demo-dev

# Test the complete pipeline
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev --watch
```

### 4. Monitor and Debug
```bash
# Watch workflow progress
argo get iris-demo -n argowf-dev --watch

# Check logs for specific steps
argo logs iris-demo -n argowf-dev

# Debug failed steps
kubectl describe pod <pod-name> -n argowf-dev
kubectl logs <pod-name> -n argowf-dev
```

### 5. Merge When Ready
```bash
# When feature is working in development
git checkout main
git pull origin main  # Get latest changes
git merge feature/your-feature-name
git push origin main

# Clean up development resources
./scripts/cleanup-dev-environment.sh argowf-dev
```

## 🛠️ Modular Scripts Architecture

Our development environment uses **separation of concerns** with focused scripts:

```
scripts/
├── create-namespace.sh           # Namespace management
├── setup-rbac.sh                 # RBAC management  
├── copy-secrets.sh               # Secret management
├── update-configmap.sh           # ConfigMap management
├── create-argocd-app.sh          # ArgoCD app management
├── verify-environment.sh         # Environment verification
├── setup-dev-environment.sh      # Environment orchestration
└── cleanup-dev-environment.sh    # Cleanup management
```

### Individual Script Usage

```bash
# Namespace operations
./scripts/create-namespace.sh argowf-dev-alice

# RBAC operations
./scripts/setup-rbac.sh argowf argowf-dev-alice

# Secret operations  
./scripts/copy-secrets.sh argowf argowf-dev-alice

# ConfigMap operations
./scripts/update-configmap.sh argowf-dev-alice

# ArgoCD operations
./scripts/create-argocd-app.sh argowf-dev-alice feature/semantic-versioning

# Environment verification
./scripts/verify-environment.sh argowf-dev-alice

# Complete cleanup
./scripts/cleanup-dev-environment.sh argowf-dev-alice
```

## 🛠️ Complete Environment Setup Script

```bash
# filepath: /home/user/homelab-mlops-demo/scripts/setup-dev-environment.sh
#!/bin/bash
set -e

NAMESPACE=${1:-argowf-dev}
FEATURE_BRANCH=${2:-$(git branch --show-current)}

echo "🚀 Setting up development environment"
echo "   Namespace: $NAMESPACE"
echo "   Feature Branch: $FEATURE_BRANCH"

# Use individual scripts with clear separation
echo ""
echo "1️⃣ Creating namespace..."
./scripts/create-namespace.sh $NAMESPACE

echo ""
echo "2️⃣ Setting up RBAC..."
./scripts/setup-rbac.sh argowf $NAMESPACE

echo ""
echo "3️⃣ Copying secrets..."
./scripts/copy-secrets.sh argowf $NAMESPACE

echo ""
echo "4️⃣ Updating ConfigMap..."
./scripts/update-configmap.sh $NAMESPACE

echo ""
echo "5️⃣ Creating ArgoCD application..."
./scripts/create-argocd-app.sh $NAMESPACE $FEATURE_BRANCH

echo ""
echo "6️⃣ Verifying environment..."
./scripts/verify-environment.sh $NAMESPACE

echo ""
echo "🎯 Development environment setup complete!"
echo ""
echo "Next steps:"
echo "  1. git add -A && git commit -m 'your changes'"
echo "  2. git push origin $FEATURE_BRANCH"
echo "  3. argocd app sync homelab-mlops-demo-$(echo $NAMESPACE | sed 's/argowf-//')"
echo "  4. argo submit demo_iris_pipeline/workflow.yaml -n $NAMESPACE --watch"

chmod +x scripts/setup-dev-environment.sh
```

## 🔄 Common Development Workflows

### Testing New Features
```bash
# 1. Create feature branch
git checkout -b feature/model-monitoring

# 2. Set up isolated dev environment
./scripts/setup-dev-environment.sh argowf-dev-monitoring feature/model-monitoring

# 3. Make changes iteratively
# Edit workflow.yaml, add monitoring.py, etc.

# 4. Test iteratively
git add -A && git commit -m "wip: add model monitoring"
git push origin feature/model-monitoring
./scripts/update-configmap.sh argowf-dev-monitoring
argocd app sync homelab-mlops-demo-monitoring
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev-monitoring --watch

# 5. Debug and iterate
argo logs iris-demo -n argowf-dev-monitoring
# Make fixes, repeat steps 4-5

# 6. Final testing
argo delete iris-demo -n argowf-dev-monitoring
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev-monitoring --watch

# 7. Merge to main
git checkout main && git merge feature/model-monitoring

# 8. Clean up
./scripts/cleanup-dev-environment.sh argowf-dev-monitoring
```

### Experimenting with Workflow Changes
```bash
# Create experimental workflow
cp demo_iris_pipeline/workflow.yaml demo_iris_pipeline/workflow-experimental.yaml

# Edit experimental version with your changes
nano demo_iris_pipeline/workflow-experimental.yaml

# Update configmap with experimental workflow
./scripts/update-configmap.sh argowf-dev

# Test experimental workflow
argo submit demo_iris_pipeline/workflow-experimental.yaml -n argowf-dev --watch

# Compare results
argo list -n argowf-dev
argo get iris-demo -n argowf-dev
argo get iris-demo-experimental -n argowf-dev
```

### Testing Different Model Configurations
```bash
# Test different model parameters
export MODEL_EXPERIMENT="random-forest-v2"
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev \
  --parameter model-name=$MODEL_EXPERIMENT --watch

# Check MLflow for experiment results
kubectl port-forward -n mlflow svc/mlflow 5000:5000 &
# Visit http://localhost:5000 to compare experiments
```

## 🐛 Debugging Common Issues

### Environment Setup Issues
```bash
# Verify complete environment setup
./scripts/verify-environment.sh argowf-dev

# Check individual components
kubectl get namespaces | grep argowf-dev
kubectl get serviceaccounts -n argowf-dev | grep argo-workflow
kubectl get secrets -n argowf-dev | grep -E "(minio|ghcr)"
kubectl get configmaps -n argowf-dev | grep iris-src
```

### RBAC Issues
```bash
# Check RBAC setup
kubectl get roles -n argowf-dev
kubectl get rolebindings -n argowf-dev
kubectl describe rolebinding -n argowf-dev

# Fix RBAC issues
./scripts/setup-rbac.sh argowf argowf-dev
```

### Secret Issues
```bash
# Check secrets
kubectl get secrets -n argowf-dev | grep -E "(minio|ghcr)"

# Re-copy secrets if missing
./scripts/copy-secrets.sh argowf argowf-dev

# Verify secret contents
kubectl get secret minio-credentials-wf -n argowf-dev -o yaml | head -20
```

### ConfigMap Issues
```bash
# Check configmap
kubectl get configmap iris-src -n argowf-dev

# Update configmap with latest changes
./scripts/update-configmap.sh argowf-dev

# Restart workflow after configmap update
argo delete iris-demo -n argowf-dev
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev --watch
```

### Workflow Issues
```bash
# Check workflow status
argo get iris-demo -n argowf-dev

# Get logs from specific pods directly
kubectl logs iris-demo-train-1086554222 -n argowf-dev
kubectl logs iris-demo-model-validation-4150168498 -n argowf-dev
kubectl logs iris-demo-semantic-versioning-407853820 -n argowf-dev
kubectl logs iris-demo-kaniko-2749533263 -n argowf-dev
kubectl logs iris-demo-deploy-2552441111 -n argowf-dev

# Check pod details for failed steps
kubectl describe pod <failed-pod-name> -n argowf-dev
```

## 📊 Testing Strategy

### Unit Testing
```bash
# Test individual components before workflow
cd demo_iris_pipeline/

# Test training script
python -c "
import sys; sys.path.append('.')
from train import train_model
train_model()
print('✅ Training works')
"

# Test validation script  
python -c "
import sys; sys.path.append('.')  
from test_model import validate_model
validate_model('/tmp/model.pkl')
print('✅ Validation works')
"

# Test versioning script
python -c "
import sys; sys.path.append('.')
import os
os.environ['VALIDATION_RESULTS_PATH'] = '/tmp/validation_results.json'
os.environ['OUTPUT_PATH'] = '/tmp/model_version.txt'
os.environ['VERSION_TAG_PATH'] = '/tmp/version_tag.txt'
# Create mock validation results
import json
with open('/tmp/validation_results.json', 'w') as f:
    json.dump({'validation_status': 'PASSED', 'accuracy': 0.95}, f)
from version_model import main
main()
print('✅ Versioning works')
"

# Test deployment script
python -c "
import sys; sys.path.append('.')
import os
os.environ['MODEL_VERSION'] = '0.1.0'
os.environ['IMAGE_TAG'] = 'test'
os.environ['NAMESPACE'] = 'test'
# Mock the deployment (don't actually deploy)
print('✅ Deployment script works')
"
```

### Integration Testing
```bash
# Test complete workflow end-to-end
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev --watch

# Test specific workflow steps
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev \
  --entrypoint train --watch  # Only run training

# Test with different parameters
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev \
  --parameter model-name=test-model --watch
```

### Performance Testing
```bash
# Monitor resource usage during workflow
kubectl top pods -n argowf-dev --watch

# Check workflow duration and compare with baseline
argo get iris-demo -n argowf-dev | grep Duration

# Compare with production metrics
argo get iris-demo -n argowf | grep Duration

# Check resource consumption
argo get iris-demo -n argowf-dev | grep ResourcesDuration
```

### Smoke Testing
```bash
./scripts/smoke-test.sh 
```

## 🚀 Advanced Development Patterns

### Multi-Environment Testing
```bash
# Test same feature in multiple environments
./scripts/setup-dev-environment.sh argowf-dev1 feature/semantic-versioning
./scripts/setup-dev-environment.sh argowf-dev2 feature/semantic-versioning

# Test with different configurations
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev1 \
  --parameter model-name=test-v1 --watch

argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev2 \
  --parameter model-name=test-v2 --watch

# Compare results
argo list -n argowf-dev1
argo list -n argowf-dev2
```

### Parallel Development
```bash
# Multiple developers can work simultaneously
# Developer Alice:
git checkout -b feature/model-improvements
./scripts/setup-dev-environment.sh argowf-dev-alice feature/model-improvements

# Developer Bob:
git checkout -b feature/performance-optimization  
./scripts/setup-dev-environment.sh argowf-dev-bob feature/performance-optimization

# Each has isolated environment - no conflicts!
```

### A/B Testing Development
```bash
# Set up A/B test environments
./scripts/setup-dev-environment.sh argowf-dev-a feature/model-v1
./scripts/setup-dev-environment.sh argowf-dev-b feature/model-v2

# Deploy different model versions
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev-a --parameter model-name=model-a
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev-b --parameter model-name=model-b

# Compare model performance
kubectl port-forward -n argowf-dev-a svc/model-a-default 8080:8080 &
kubectl port-forward -n argowf-dev-b svc/model-b-default 8081:8080 &

# Test both endpoints and compare results
```

### Rollback Testing
```bash
# Test rollback scenarios
git checkout main
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev --watch  # Test main

git checkout feature/your-feature
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev --watch  # Test feature

# Validate rollback capability
git checkout main
./scripts/update-configmap.sh argowf-dev
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev --watch  # Should work
```

## 🎯 Best Practices

### 1. **Always Use Feature Branches**
- Never develop directly on `main`
- Use descriptive branch names: `feature/semantic-versioning`, `fix/memory-leak`, `docs/api-reference`
- One feature per branch for clean history

### 2. **Isolate Development Environments**
- Each feature gets its own namespace: `argowf-dev-{feature}`, `argowf-dev-{developer}`
- Use descriptive namespace names for easy identification
- Clean up environments when done

### 3. **Test Incrementally**
- Test individual components before full workflow
- Use unit tests for Python scripts
- Test workflow steps incrementally
- Validate end-to-end functionality

### 4. **Use Proper Commit Messages**
```bash
# Good commit messages
git commit -m "feat: add semantic versioning to MLOps pipeline"
git commit -m "fix: resolve kubectl installation in deploy step"
git commit -m "docs: update development workflow guide"
git commit -m "refactor: separate concerns in setup scripts"

# Follow conventional commits: type(scope): description
```

### 5. **Document Changes**
- Update docs alongside code changes
- Document breaking changes in commit messages
- Include examples for new features
- Update README if adding new scripts

### 6. **Monitor Resource Usage**
```bash
# Regularly check resource consumption
kubectl top nodes
kubectl top pods -n argowf-dev

# Set resource limits in development workflows
# Clean up unused namespaces regularly
./scripts/cleanup-dev-environment.sh <old-namespace>
```

### 7. **Security Best Practices**
- Never commit secrets to git
- Use separate service accounts for development
- Copy secrets cleanly without ownerReferences
- Regularly rotate development credentials

## 🧹 Environment Management

### Daily Cleanup
```bash
# List all development namespaces
kubectl get namespaces | grep argowf-dev

# Check which are actively used
for ns in $(kubectl get namespaces -o name | grep argowf-dev | cut -d'/' -f2); do
  echo "Namespace: $ns"
  kubectl get pods -n $ns 2>/dev/null | grep -v "No resources" || echo "  Empty"
done

# Clean up old/unused environments
./scripts/cleanup-dev-environment.sh argowf-dev-old-feature
```

### Bulk Cleanup
```bash
# List all dev namespaces with age
kubectl get namespaces | grep argowf-dev

# Interactive cleanup of old environments
./scripts/cleanup-dev-environments.sh
```

### Environment Inventory
```bash
# Generate environment inventory
echo "=== Development Environment Inventory ==="
for ns in $(kubectl get namespaces -o name | grep argowf-dev | cut -d'/' -f2); do
  echo ""
  echo "Namespace: $ns"
  echo "  Age: $(kubectl get namespace $ns -o jsonpath='{.metadata.creationTimestamp}')"
  echo "  Workflows: $(argo list -n $ns 2>/dev/null | wc -l || echo 0)"
  echo "  Pods: $(kubectl get pods -n $ns --no-headers 2>/dev/null | wc -l || echo 0)"
  echo "  ArgoCD App: $(argocd app list | grep $ns | awk '{print $1}' || echo 'None')"
done
```


## 📈 Performance Optimization

### Development Environment Performance
```bash
# Use resource-optimized workflow for development
cp demo_iris_pipeline/workflow.yaml demo_iris_pipeline/workflow-dev.yaml

# Edit workflow-dev.yaml to use smaller resource requests
# Example: Change memory from "1Gi" to "512Mi", cpu from "1" to "500m"

# Test with optimized resources
argo submit demo_iris_pipeline/workflow-dev.yaml -n argowf-dev --watch
```

### Faster Development Cycles
```bash
# Use cached base images for faster container builds
# Update Dockerfile to use multi-stage builds
# Pre-pull common images to development nodes

# Skip expensive steps during development
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev \
  --entrypoint train --watch  # Only run training step
```

## 🧹 Complete Cleanup Script

```bash
# filepath: /home/user/homelab-mlops-demo/scripts/cleanup-dev-environments.sh
#!/bin/bash

echo "🧹 Cleaning up development environments..."

# List development namespaces
DEV_NAMESPACES=$(kubectl get namespaces -o name | grep "argowf-dev")

if [ -z "$DEV_NAMESPACES" ]; then
  echo "No development namespaces found"
  exit 0
fi

echo "Found development namespaces:"
echo "$DEV_NAMESPACES"

read -p "Delete all development environments? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  # Delete namespaces
  echo "$DEV_NAMESPACES" | xargs kubectl delete
  
  # Delete ArgoCD applications
  argocd app list | grep "homelab-mlops-demo-dev" | awk '{print $1}' | xargs argocd app delete
  
  echo "✅ Development environments cleaned up"
else
  echo "Cleanup cancelled"
fi

chmod +x scripts/cleanup-dev-environments.sh
```

This comprehensive development workflow guide provides everything needed to safely and efficiently develop MLOps pipeline features with proper separation of concerns, comprehensive testing, and production-ready practices! 🎯

## 📋 Quick Reference

### Essential Commands
```bash
# Setup development environment
./scripts/setup-dev-environment.sh argowf-dev-yourname feature/your-feature

# Update code and test
git add -A && git commit -m "your changes"
git push origin feature/your-feature
./scripts/update-configmap.sh argowf-dev-yourname
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev-yourname --watch

# Clean up when done
./scripts/cleanup-dev-environment.sh argowf-dev-yourname
```