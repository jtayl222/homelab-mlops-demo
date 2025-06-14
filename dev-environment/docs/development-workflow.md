# Development Workflow Guide

This guide explains how to safely develop and test new features using feature branches and isolated development environments with proper separation of concerns.

## 🎯 Overview

Our MLOps pipeline uses **GitOps principles** with **kustomize overlays** for environment management:
- **`main` branch** → **`argowf` namespace** (Production) → `manifests/overlays/production`
- **Feature branches** → **`argowf-dev*` namespaces** (Development) → `manifests/overlays/development`

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
# Set up complete development environment with kustomize
make deploy-dev

# Or use the script directly
./scripts/restart-demo.sh argowf-dev deploy

# Or with custom namespace
./scripts/restart-demo.sh argowf-dev-yourname deploy
```

### 3. Develop and Test
```bash
# Make your changes to the MLOps pipeline
# Edit workflow files, Python scripts, kustomize configs, etc.

# Test changes locally first (if possible)
python demo_iris_pipeline/src/train.py  # Test training script
python demo_iris_pipeline/src/test_model.py  # Test validation

# Commit and push changes
git add .
git commit -m "feat: add semantic versioning to MLOps pipeline"
git push origin feature/your-feature-name

# Deploy changes to development environment
make deploy-dev

# Test the complete pipeline
make demo-dev

# Or manually submit workflow
argo submit manifests/base/workflows/iris-workflow.yaml -n argowf-dev --watch
```

### 4. Monitor and Debug
```bash
# Use makefile targets for easier debugging
make workflow-status           # Check workflow status
make port-forward-dev         # Port forward development service
make smoke-test-dev          # Run automated tests

# Or use direct commands
argo get iris-demo -n argowf-dev --watch
argo logs iris-demo -n argowf-dev
kubectl describe pod <pod-name> -n argowf-dev
kubectl logs <pod-name> -n argowf-dev
```

### 5. Test Model Predictions
```bash
# Get dynamic port configuration
DEV_PORT=$(make show-config | grep "Development port" | cut -d: -f2 | tr -d ' ')

# Port forward and test
kubectl port-forward -n argowf-dev svc/dev-iris-0-2-0-default-classifier $DEV_PORT:$DEV_PORT &

# Test prediction with dynamic port
curl -X POST http://localhost:$DEV_PORT/api/v1.0/predictions \
  -H 'Content-Type: application/json' \
  -d '{"data":{"ndarray":[[5.1,3.5,1.4,0.2]]}}'

# Or use makefile target
make smoke-test-dev
```

### 6. Merge When Ready
```bash
# When feature is working in development
git checkout main
git pull origin main  # Get latest changes
git merge feature/your-feature-name
git push origin main

# Clean up development resources
make cleanup
```

## 🛠️ Kustomize-Based Configuration Management

Our environment uses **centralized port configuration** with kustomize overlays:

```
manifests/
├── base/                     # Base configuration
│   ├── configmaps/
│   │   ├── app-config.yaml  # Central port configuration
│   │   └── iris-src-configmap.yaml
│   ├── workflows/
│   └── ...
└── overlays/                 # Environment-specific overrides
    ├── development/
    │   ├── kustomization.yaml
    │   └── app-config-patch.yaml  # Dev-specific ports
    └── production/
        └── kustomization.yaml
```

### Configuration Commands
```bash
# View current configuration
make show-config

# Preview what will be deployed
make preview-dev      # Development environment
make preview-prod     # Production environment

# Validate configuration
make validate-kustomize

# Check for remaining hardcoded ports
make clean-ports
```

## 🔄 Environment-Specific Development

### Development Environment
```bash
# Deploy development overlay
make deploy-dev

# Configuration includes:
# - Namespace: argowf-dev
# - Name prefix: dev-
# - Model serving port: 9001 (default)
# - Resource limits: Optimized for development

# Test development deployment
make demo-dev
make smoke-test-dev
```

### Production Environment
```bash
# Deploy production overlay
make deploy-prod

# Configuration includes:
# - Namespace: argowf
# - Model serving port: 9000 (default)
# - Resource limits: Production-ready

# Test production deployment
make demo-prod
make smoke-test-prod
```

## 🔧 Common Development Workflows

### Testing New Features
```bash
# 1. Create feature branch
git checkout -b feature/model-monitoring

# 2. Deploy development environment
make deploy-dev

# 3. Make changes iteratively
# Edit files, update configurations

# 4. Test iteratively with kustomize
git add -A && git commit -m "wip: add model monitoring"
git push origin feature/model-monitoring
make deploy-dev
make demo-dev

# 5. Debug and iterate
make workflow-status
argo logs iris-demo -n argowf-dev
# Make fixes, repeat steps 4-5

# 6. Final testing
make cleanup
make deploy-dev
make demo-dev

# 7. Merge to main
git checkout main && git merge feature/model-monitoring

# 8. Clean up
make cleanup
```

### Testing Configuration Changes
```bash
# Edit base configuration
nano manifests/base/configmaps/app-config.yaml

# Or edit development overlay
nano manifests/overlays/development/app-config-patch.yaml

# Preview changes
make preview-dev

# Validate changes
make validate-kustomize

# Deploy changes
make deploy-dev

# Test with new configuration
make demo-dev
```

### Multi-Environment Testing
```bash
# Test in both environments
make deploy-dev
make demo-dev

make deploy-prod  
make demo-prod

# Compare configurations
make show-config
make check-ports
```

## 🐛 Debugging Common Issues

### Environment Setup Issues
```bash
# Verify environment setup
make validate-kustomize

# Check kustomize output
make preview-dev | less
make preview-prod | less

# Verify configuration
make show-config
make check-ports
```

### Port Configuration Issues
```bash
# Check current port configuration
make show-config

# Verify port assignments
kubectl get configmap -n argowf-dev dev-app-config -o yaml
kubectl get configmap -n argowf app-config -o yaml

# Test port connectivity
make port-forward-dev  # In one terminal
make smoke-test-dev    # In another terminal
```

### Kustomize Issues
```bash
# Validate kustomization files
kubectl kustomize manifests/overlays/development --dry-run
kubectl kustomize manifests/overlays/production --dry-run

# Check for validation errors
make validate-kustomize

# Fix common issues
kubectl kustomize manifests/overlays/development > /tmp/debug-dev.yaml
kubectl apply --dry-run=client -f /tmp/debug-dev.yaml
```

### Model Serving Issues
```bash
# Check model deployment status
kubectl get seldondeployment -n argowf-dev
kubectl describe seldondeployment -n argowf-dev

# Check model pods
kubectl get pods -n argowf-dev | grep classifier
kubectl logs -n argowf-dev <classifier-pod>

# Test model endpoint with correct port
DEV_PORT=$(./scripts/get-config.sh development)
kubectl port-forward -n argowf-dev svc/dev-iris-0-2-0-default-classifier $DEV_PORT:$DEV_PORT &
curl -X POST http://localhost:$DEV_PORT/api/v1.0/predictions \
  -H 'Content-Type: application/json' \
  -d '{"data":{"ndarray":[[5.1,3.5,1.4,0.2]]}}'
```

## 📊 Testing Strategy

### Configuration Testing
```bash
# Test configuration extraction
./scripts/get-config.sh development
./scripts/get-config.sh production

# Test makefile configuration
make show-config

# Validate all environments
make validate-kustomize
```

### Integration Testing
```bash
# Test complete pipeline with dynamic configuration
make deploy-dev
make demo-dev
make smoke-test-dev

# Test production pipeline
make deploy-prod
make demo-prod
make smoke-test-prod
```

### Performance Testing
```bash
# Monitor resource usage with proper limits
kubectl top pods -n argowf-dev --containers

# Compare development vs production resource usage
kubectl describe pod -n argowf-dev | grep -A5 "Limits"
kubectl describe pod -n argowf | grep -A5 "Limits"
```

## 🚀 Advanced Development Patterns

### Custom Port Configuration
```bash
# Edit development overlay to use custom port
cat > manifests/overlays/development/app-config-patch.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  MODEL_SERVING_PORT: "9002"  # Custom development port
  MODEL_METRICS_PORT: "6002"
EOF

# Deploy with custom configuration
make deploy-dev

# Verify custom port is used
make show-config
```

### Environment-Specific Resource Limits
```bash
# Add resource limits patch for development
cat > manifests/overlays/development/resource-limits-patch.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: iris-demo
spec:
  templates:
  - name: train
    container:
      resources:
        requests:
          memory: "512Mi"
          cpu: "250m"
        limits:
          memory: "1Gi"
          cpu: "500m"
EOF

# Update kustomization to include resource patch
echo "  - path: resource-limits-patch.yaml" >> manifests/overlays/development/kustomization.yaml

# Deploy with resource limits
make deploy-dev
```

### A/B Testing with Different Configurations
```bash
# Create custom overlay for A/B testing
mkdir -p manifests/overlays/ab-test
cp -r manifests/overlays/development/* manifests/overlays/ab-test/

# Modify configuration for A/B test
sed -i 's/9001/9003/g' manifests/overlays/ab-test/app-config-patch.yaml

# Deploy A/B test environment
kubectl apply -k manifests/overlays/ab-test

# Compare results
make show-config
kubectl get pods -n argowf-dev | grep classifier
kubectl get pods -n argowf-ab-test | grep classifier
```

## 🎯 Best Practices

### 1. **Use Centralized Configuration**
- All port configurations in `manifests/base/configmaps/app-config.yaml`
- Environment-specific overrides in overlay patches
- Never hardcode ports in scripts or documentation

### 2. **Validate Before Deploy**
```bash
# Always validate before deploying
make validate-kustomize
make preview-dev  # Review what will be deployed
make deploy-dev   # Deploy after validation
```

### 3. **Use Makefile Targets**
```bash
# Use consistent makefile targets instead of raw commands
make deploy-dev        # Instead of kubectl apply -k ...
make demo-dev         # Instead of argo submit ...
make smoke-test-dev   # Instead of manual curl commands
make show-config      # Instead of manual config extraction
```

### 4. **Monitor Configuration Drift**
```bash
# Regularly check for hardcoded references
make clean-ports

# Verify configuration consistency
make check-ports

# Validate all environments
make validate-kustomize
```

## 🧹 Environment Management

### Configuration Management
```bash
# List current configurations
make show-config

# Check for configuration drift
make clean-ports

# Update configuration centrally
nano manifests/base/configmaps/app-config.yaml
make validate-kustomize
make deploy-dev
make deploy-prod
```

### Resource Management
```bash
# Check resource usage across environments
kubectl top pods -n argowf-dev
kubectl top pods -n argowf

# Monitor configuration consistency
make check-ports
make workflow-status
```

## 📋 Quick Reference

### Essential Commands
```bash
# Configuration management
make show-config         # Show current port configuration
make validate-kustomize  # Validate all kustomizations
make preview-dev        # Preview development manifests
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
```

### Configuration Files
```bash
# Base configuration
manifests/base/configmaps/app-config.yaml     # Central port configuration

# Environment-specific overrides
manifests/overlays/development/app-config-patch.yaml  # Development ports
manifests/overlays/production/kustomization.yaml     # Production config

# Kustomize overlays
manifests/overlays/development/kustomization.yaml     # Development overlay
manifests/overlays/production/kustomization.yaml      # Production overlay
```

This updated development workflow now uses the centralized kustomize configuration for all port management, eliminating hardcoded values and providing consistent, environment-aware configuration! 🎯