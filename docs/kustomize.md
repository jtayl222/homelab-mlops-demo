# Kustomize Configuration Guide

This document explains the Kustomize configuration structure used in the Homelab MLOps Demo project for managing Kubernetes deployments across different environments.

## Overview

The project uses Kustomize to manage Kubernetes configurations with a base + overlays pattern, allowing for environment-specific customizations while maintaining a common base configuration.

## Directory Structure

```
k8s/
├── applications/
│   └── iris-demo/
│       ├── base/                    # Base Kubernetes manifests
│       │   ├── configmap.yaml
│       │   ├── kustomization.yaml
│       │   ├── namespace.yaml
│       │   ├── rbac.yaml
│       │   ├── rclone-config.yaml
│       │   ├── sealed-secrets/      # Sealed secrets for secure credential management
│       │   │   ├── iris-demo-ghcr.yaml
│       │   │   ├── iris-demo-minio.yaml
│       │   │   └── iris-demo-mlflow.yaml
│       │   └── workflow.yaml
│       └── overlays/
│           └── dev/                 # Development environment customizations
│               ├── allow-taskresults.yaml
│               ├── kustomization.yaml
│               ├── resource-limits.json
│               ├── resource-limits.yaml
│               └── seldon-deploy-rbac.yaml
└── platform/                       # Platform-level configurations
```

## Base Configuration

The `base/` directory contains the foundational Kubernetes manifests that are common across all environments:

### Core Components

- **namespace.yaml**: Defines the `iris-demo` namespace for isolating the application resources
- **configmap.yaml**: Application configuration data and environment variables
- **rbac.yaml**: Role-based access control configurations for the MLOps pipeline
- **workflow.yaml**: Argo Workflows definition for the ML pipeline execution
- **rclone-config.yaml**: Configuration for data synchronization with external storage

### Sealed Secrets

The `sealed-secrets/` directory contains encrypted secrets that can be safely stored in version control:

- **iris-demo-ghcr.yaml**: GitHub Container Registry authentication
- **iris-demo-minio.yaml**: MinIO object storage credentials
- **iris-demo-mlflow.yaml**: MLflow tracking server authentication

> **Note**: These are sealed secrets created using the Bitnami Sealed Secrets controller, which encrypts regular Kubernetes secrets for safe storage in Git repositories.

## Development Overlay

The `overlays/dev/` directory contains development-specific customizations:

### Key Files

- **kustomization.yaml**: Defines patches, resource modifications, and additional resources for dev
- **resource-limits.yaml**: Development-appropriate CPU and memory limits
- **resource-limits.json**: JSON format resource constraints for specific components
- **allow-taskresults.yaml**: Permissions for Argo Workflows task result storage
- **seldon-deploy-rbac.yaml**: Additional RBAC rules for Seldon model deployment

## Kustomization Files

### Base Kustomization

The base `kustomization.yaml` typically includes:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - configmap.yaml
  - rbac.yaml
  - rclone-config.yaml
  - workflow.yaml
  - sealed-secrets/iris-demo-ghcr.yaml
  - sealed-secrets/iris-demo-minio.yaml
  - sealed-secrets/iris-demo-mlflow.yaml

commonLabels:
  app: iris-demo
  project: homelab-mlops
```

### Dev Overlay Kustomization

The dev overlay `kustomization.yaml` typically includes:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base
  - allow-taskresults.yaml
  - seldon-deploy-rbac.yaml

patchesStrategicMerge:
  - resource-limits.yaml

commonLabels:
  environment: dev
```

## Usage

### Building Manifests

To generate the final Kubernetes manifests for a specific environment:

```bash
# Build dev environment manifests
kustomize build k8s/applications/iris-demo/overlays/dev

# Apply directly to cluster
kustomize build k8s/applications/iris-demo/overlays/dev | kubectl apply -f -
```

### Validation

Validate the Kustomize configuration:

```bash
# Validate the base configuration
kustomize build k8s/applications/iris-demo/base --dry-run

# Validate the dev overlay
kustomize build k8s/applications/iris-demo/overlays/dev --dry-run
```

## Integration with ArgoCD

This Kustomize structure is designed to work seamlessly with ArgoCD for GitOps deployments:

1. ArgoCD applications point to the overlay directories
2. Changes to the Git repository trigger automatic deployments
3. Environment-specific configurations are maintained through overlays

### ArgoCD Application Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: iris-demo-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/jtayl222/homelab-mlops-demo
    targetRevision: main
    path: k8s/applications/iris-demo/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: iris-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Best Practices

### Resource Management

- Use resource limits and requests in overlays to prevent resource contention
- Apply appropriate resource constraints for each environment
- Monitor resource usage and adjust limits as needed

### Secret Management

- Use Sealed Secrets for sensitive data that needs to be stored in Git
- Rotate sealed secrets regularly
- Keep unsealed secrets out of version control

### Environment Separation

- Use distinct namespaces for different environments
- Apply environment-specific labels for easy identification
- Maintain separate overlay directories for each environment

### Configuration Management

- Keep environment-agnostic configuration in the base
- Use overlays for environment-specific modifications
- Validate configurations before deployment

## Troubleshooting

### Common Issues

1. **Resource conflicts**: Ensure unique names across environments
2. **Secret decryption failures**: Verify Sealed Secrets controller is running
3. **RBAC issues**: Check service account permissions and role bindings
4. **Workflow failures**: Validate Argo Workflows RBAC and resource access

### Debugging Commands

```bash
# Check applied resources
kubectl get all -n iris-demo

# Verify sealed secrets
kubectl get sealedsecrets -n iris-demo

# Check workflow status
kubectl get workflows -n iris-demo

# View logs
kubectl logs -l app=iris-demo -n iris-demo
```

## Contributing

When adding new components or environments:

1. Add common configuration to the base directory
2. Create environment-specific overlays as needed
3. Update this documentation with new components
4. Test configurations before merging
5. Ensure proper RBAC permissions are in place

## Related Documentation

- [ArgoCD Setup](../docs/argocd-setup.md)
- [Sealed Secrets Management](../docs/sealed-secrets.md)
- [Environment Configuration](../docs/environment-config.md)
- [Troubleshooting Guide](troubleshooting-simple.md)