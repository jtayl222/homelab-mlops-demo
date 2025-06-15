# Kustomize in MLOps: Configuration Management at Scale

## Why Kustomize is Required

### **The Configuration Complexity Problem**

In production MLOps platforms, you face a configuration management nightmare:

```yaml
# Same application, different environments
dev-cluster/
├── iris-model-v1.2.0-dev
├── resource-limits: 100m CPU, 256Mi RAM  
├── replicas: 1
├── storage: local-path
└── monitoring: basic

staging-cluster/
├── iris-model-v1.2.0-staging
├── resource-limits: 500m CPU, 1Gi RAM
├── replicas: 2  
├── storage: NFS with backups
└── monitoring: full observability

production-cluster/
├── iris-model-v1.1.5-prod  # Different version!
├── resource-limits: 2 CPU, 4Gi RAM
├── replicas: 5 with HPA
├── storage: distributed with replication
└── monitoring: SLA tracking + alerting
```

**Without Kustomize**: You maintain 3+ copies of nearly identical YAML files, leading to:
- Configuration drift between environments
- Manual synchronization errors
- Security vulnerabilities (secrets in wrong places)
- Deployment failures due to copy-paste mistakes

### **The MLOps-Specific Challenges**

MLOps adds unique configuration complexity:

#### **1. Model Versioning**
```yaml
# Different model versions per environment
containers:
- name: iris-classifier
  image: ghcr.io/jtayl222/iris:v1.2.0-dev    # Development
  image: ghcr.io/jtayl222/iris:v1.1.5-prod   # Production
```

#### **2. Resource Requirements**
```yaml
# Training workloads need different resources than serving
resources:
  training:
    requests: { cpu: "4", memory: "8Gi", nvidia.com/gpu: "1" }
  serving:
    requests: { cpu: "100m", memory: "256Mi" }
```

#### **3. Data Source Configuration**
```yaml
# Different data sources per environment
env:
- name: MLFLOW_TRACKING_URI
  value: "http://mlflow-dev.mlflow.svc.cluster.local:5000"     # Dev
  value: "https://mlflow.company.com"                          # Prod
- name: S3_BUCKET
  value: "ml-models-dev"      # Dev
  value: "ml-models-prod"     # Prod
```

## Current Project Architecture

### **Existing Structure**
```
manifests/
├── configmaps/
│   └── iris-src-configmap.yaml         # Single environment
├── secrets/
│   └── rclone-config.yaml             # Hardcoded values
├── workflows/
│   └── iris-workflow.yaml             # Environment-specific
└── rbac/
    └── argo-workflows-rbac.yaml       # Static configuration
```

### **Problems with Current Approach**
1. **Single Environment Only**: Everything hardcoded for `argowf` namespace
2. **No Environment Promotion**: Can't easily promote models dev → staging → prod
3. **Secret Management**: Credentials hardcoded in YAML files
4. **Resource Limits**: Fixed CPU/memory regardless of environment
5. **No Multi-Tenancy**: Can't isolate different teams/projects

## Kustomize Solution

### **Proposed Structure**
```
k8s/
├── base/                              # Common configuration
│   ├── kustomization.yaml
│   ├── iris-workflow.yaml            # Base workflow template
│   ├── seldon-deployment.yaml        # Base serving config
│   ├── mlflow-config.yaml            # Base MLflow setup
│   └── rbac.yaml                     # Base permissions
├── overlays/
│   ├── development/
│   │   ├── kustomization.yaml        # Dev-specific patches
│   │   ├── resource-limits.yaml     # Small resources
│   │   ├── replicas.yaml            # Single replica
│   │   └── secrets.yaml             # Dev credentials
│   ├── staging/
│   │   ├── kustomization.yaml        # Staging patches
│   │   ├── resource-limits.yaml     # Medium resources
│   │   ├── replicas.yaml            # 2 replicas
│   │   └── secrets.yaml             # Staging credentials
│   └── production/
│       ├── kustomization.yaml        # Prod patches
│       ├── resource-limits.yaml     # Large resources
│       ├── replicas.yaml            # Auto-scaling enabled
│       ├── secrets.yaml             # Prod credentials
│       └── security-policies.yaml   # Prod-only security
└── components/                        # Reusable pieces
    ├── monitoring/
    ├── backup/
    └── security/
```

### **Example Implementation**

#### **Base Configuration** (`k8s/base/kustomization.yaml`)
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- iris-workflow.yaml
- seldon-deployment.yaml
- mlflow-config.yaml
- rbac.yaml

configMapGenerator:
- name: iris-config
  files:
  - train.py=../../demo_iris_pipeline/src/train.py
  - serve.py=../../demo_iris_pipeline/src/serve.py
  - requirements.txt=../../demo_iris_pipeline/src/requirements.txt
```

#### **Development Overlay** (`k8s/overlays/development/kustomization.yaml`)
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: iris-dev

resources:
- ../../base

patchesStrategicMerge:
- resource-limits.yaml
- replicas.yaml

secretGenerator:
- name: minio-credentials
  literals:
  - access-key=dev-access-key
  - secret-key=dev-secret-key
  
images:
- name: ghcr.io/jtayl222/iris
  newTag: dev-latest

commonLabels:
  environment: development
  team: ml-platform
```

#### **Production Overlay** (`k8s/overlays/production/kustomization.yaml`)
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: iris-prod

resources:
- ../../base
- ../../components/monitoring
- ../../components/backup
- ../../components/security

patchesStrategicMerge:
- resource-limits.yaml
- replicas.yaml
- security-policies.yaml

secretGenerator:
- name: minio-credentials
  literals:
  - access-key=prod-access-key
  - secret-key=prod-secret-key

images:
- name: ghcr.io/jtayl222/iris
  newTag: v1.1.5  # Pinned production version

commonLabels:
  environment: production
  team: ml-platform
  
commonAnnotations:
  deployment.kubernetes.io/revision: "42"
  owner: "ml-platform-team@company.com"
```

## Deployment Workflow

### **Environment Promotion Pipeline**
```bash
# Deploy to development
kubectl apply -k k8s/overlays/development

# Run tests, validate model performance
./scripts/validate-deployment.sh iris-dev

# Promote to staging  
kubectl apply -k k8s/overlays/staging

# Run integration tests
./scripts/integration-tests.sh iris-staging

# Deploy to production (with approval)
kubectl apply -k k8s/overlays/production
```

### **GitOps Integration with ArgoCD**
```yaml
# argocd-applications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: iris-dev
spec:
  source:
    repoURL: https://github.com/jtayl222/homelab-mlops-demo
    targetRevision: main
    path: k8s/overlays/development
  destination:
    namespace: iris-dev
---
apiVersion: argoproj.io/v1alpha1  
kind: Application
metadata:
  name: iris-prod
spec:
  source:
    repoURL: https://github.com/jtayl222/homelab-mlops-demo
    targetRevision: v1.1.5  # Tag-based deployments for prod
    path: k8s/overlays/production
  destination:
    namespace: iris-prod
```

## Alternatives to Kustomize

### **1. Helm**
**Pros**:
- Template-based approach
- Package management
- Large ecosystem
- Version management

**Cons**:
- Complex templating language
- "Helm hell" with complex dependencies
- Requires Tiller (v2) or complicated RBAC (v3)
- Over-engineering for simple use cases

**Best For**: Complex applications with many dependencies, third-party chart ecosystem

### **2. Plain YAML + Bash**
**Pros**:
- Simple to understand
- No additional tooling
- Direct kubectl apply

**Cons**:
- Error-prone manual management
- No DRY principle
- Configuration drift
- Difficult secret management

**Best For**: Single environment, simple deployments, proof-of-concepts

### **3. Jsonnet**
**Pros**:
- Powerful templating
- Data templating language
- Good for complex configurations

**Cons**:
- Learning curve
- Limited Kubernetes ecosystem
- Debugging complexity
- Over-engineering for many use cases

**Best For**: Complex configuration generation, teams with strong programming skills

### **4. Pulumi/CDK**
**Pros**:
- Infrastructure as code
- Programming language familiarity
- Type safety
- Cross-cloud support

**Cons**:
- State management complexity
- Different mental model from kubectl
- Requires programming skills
- Additional tooling overhead

**Best For**: Infrastructure + application deployment, teams preferring code over YAML

### **Comparison Matrix**

| Tool | Learning Curve | MLOps Fit | Multi-Env | Secret Mgmt | Ecosystem |
|------|---------------|-----------|-----------|-------------|-----------|
| **Kustomize** | Low | ⭐⭐⭐⭐⭐ | Excellent | Good | Native K8s |
| **Helm** | Medium | ⭐⭐⭐⭐ | Good | Excellent | Huge |
| **Plain YAML** | None | ⭐⭐ | Poor | Poor | N/A |
| **Jsonnet** | High | ⭐⭐⭐ | Good | Good | Small |
| **Pulumi** | High | ⭐⭐⭐ | Excellent | Excellent | Growing |

## Gaps in Current Project & Future Work

### **Immediate Gaps**

#### **1. No Multi-Environment Support**
```yaml
# Current: Single environment hardcoded
metadata:
  namespace: argowf  # Hardcoded everywhere

# Needed: Environment-specific configuration
metadata:
  namespace: iris-${ENVIRONMENT}
```

#### **2. Secret Management Anti-Patterns**
```yaml
# Current: Secrets in plain YAML
stringData:
  rclone.conf: |
    access_key_id = ${MINIO_ACCESS_KEY}    # Environment variable
    secret_access_key = ${MINIO_SECRET_KEY} # Not encrypted at rest
```

#### **3. No Resource Governance**
```yaml
# Current: No resource limits
containers:
- name: iris-classifier
  # No resource requests/limits defined
  # Could consume entire node
```

#### **4. Hardcoded Infrastructure References**
```yaml
# Current: Hardcoded service names
env:
- name: MLFLOW_TRACKING_URI
  value: "http://mlflow.mlflow.svc.cluster.local:5000"  # Hardcoded
```

### **Future Work Roadmap**

#### **Phase 1: Basic Kustomization (Week 1-2)**
- [ ] Convert existing manifests to kustomize base
- [ ] Create dev/staging/prod overlays
- [ ] Implement proper secret management
- [ ] Add resource limits and requests

#### **Phase 2: Advanced Configuration (Week 3-4)**  
- [ ] Multi-tenancy support (team namespaces)
- [ ] External secrets integration (Vault/AWS Secrets Manager)
- [ ] Network policies for environment isolation
- [ ] Custom resource definitions for MLOps primitives

#### **Phase 3: GitOps Integration (Week 5-6)**
- [ ] ArgoCD application sets for multi-environment
- [ ] Automated promotion pipelines
- [ ] Policy-as-code with OPA Gatekeeper
- [ ] Compliance scanning and reporting

#### **Phase 4: Production Hardening (Week 7-8)**
- [ ] Pod security policies/standards
- [ ] Image vulnerability scanning
- [ ] Resource quotas and limit ranges
- [ ] Disaster recovery procedures

### **Technical Debt to Address**

#### **1. Configuration Sprawl**
```bash
# Current scattered config files
find . -name "*.yaml" | wc -l
# 47 YAML files in different directories

# Target: Centralized configuration management
k8s/
├── base/           # 5 base templates
└── overlays/       # 3 environment overlays
```

#### **2. Testing Gap**
```bash
# Current: No configuration testing
# Needed: Kustomize build validation
kustomize build k8s/overlays/production | kubeval
kustomize build k8s/overlays/production | kubectl apply --dry-run=server -f -
```

#### **3. Documentation Debt**
- [ ] Environment-specific deployment guides
- [ ] Troubleshooting runbooks per environment  
- [ ] Configuration parameter documentation
- [ ] Security review procedures

### **Scaling Challenges to Solve**

#### **1. Multi-Model Management**
```yaml
# Current: Single iris model
# Future: Multiple models per environment
overlays/
├── production/
│   ├── iris-v1.1.5/
│   ├── fraud-detection-v2.3.1/
│   └── recommendation-engine-v1.8.2/
```

#### **2. Cross-Cluster Deployments**
```yaml
# Current: Single cluster
# Future: Multi-region, multi-cloud
overlays/
├── aws-us-east-1/
├── aws-eu-west-1/
├── gcp-us-central1/
└── on-premises/
```

#### **3. Compliance and Governance**
```yaml
# Future: Policy enforcement
policies/
├── data-residency.yaml      # GDPR compliance
├── model-approval.yaml      # Model governance
├── security-scanning.yaml   # Vulnerability management
└── audit-logging.yaml      # Compliance trails
```

## Getting Started

### **Quick Migration Path**
```bash
# 1. Create kustomize structure
mkdir -p k8s/{base,overlays/{dev,staging,prod}}

# 2. Move existing manifests to base
cp manifests/workflows/* k8s/base/
cp manifests/secrets/* k8s/base/

# 3. Create base kustomization  
cat > k8s/base/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- iris-workflow.yaml
- rclone-config.yaml
EOF

# 4. Test the build
kustomize build k8s/base

# 5. Create first overlay
cat > k8s/overlays/dev/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: iris-dev
resources:
- ../../base
EOF

# 6. Deploy to dev
kubectl apply -k k8s/overlays/dev
```

### **Validation Commands**
```bash
# Validate kustomize syntax
kustomize build k8s/overlays/production

# Check differences between environments  
diff <(kustomize build k8s/overlays/dev) <(kustomize build k8s/overlays/prod)

# Dry-run deployment
kustomize build k8s/overlays/staging | kubectl apply --dry-run=server -f -
```

## Conclusion

Kustomize bridges the gap between simple YAML files and complex templating systems. For MLOps platforms, it provides:

- **Environment Parity**: Same configuration patterns across dev/staging/prod
- **Secret Management**: Proper handling of credentials and sensitive data
- **Resource Governance**: Environment-appropriate resource allocation
- **GitOps Ready**: Native integration with ArgoCD and similar tools

The current project demonstrates MLOps capabilities but lacks production-ready configuration management. Kustomize provides the missing pieces for enterprise deployment patterns.

**Next Steps**: Start with Phase 1 (basic kustomization) to gain immediate benefits, then gradually adopt advanced patterns as your MLOps platform matures.