# 🔍 Simple Troubleshooting Guide

### Common Issues and Solutions

#### "ServiceAccount not found"
```bash
# Check service account exists
kubectl get serviceaccount argo-workflow -n argowf-dev

# Recreate if missing
./scripts/setup-rbac.sh argowf argowf-dev
```

#### "ConfigMap not found"
```bash
# Check configmap exists
kubectl get configmap iris-src -n argowf-dev

# Recreate if missing
./scripts/update-configmap.sh argowf-dev
```

#### "Secret not found"
```bash
# Check secrets exist
kubectl get secrets -n argowf-dev | grep -E "(minio|ghcr)"

# Recreate if missing
./scripts/copy-secrets.sh argowf argowf-dev
```

#### "RBAC forbidden errors"
```bash
# Check RBAC setup
kubectl get roles,rolebindings -n argowf-dev

# Fix RBAC
./scripts/setup-rbac.sh argowf argowf-dev
```

#### "Workflow stuck or failing"
```bash
# Check workflow status
argo get iris-demo -n argowf-dev

# Check individual step logs
argo logs iris-demo -n argowf-dev --container <step-name>

# Delete and restart
argo delete iris-demo -n argowf-dev
argo submit demo_iris_pipeline/workflow.yaml -n argowf-dev --watch
```

#### "ArgoCD sync issues"
```bash
# Check ArgoCD application status
argocd app get homelab-mlops-demo-dev

# Force sync
argocd app sync homelab-mlops-demo-dev --force

# Check for conflicts
argocd app diff homelab-mlops-demo-dev
```
