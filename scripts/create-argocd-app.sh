#!/bin/bash
# create-argocd-app.sh - ArgoCD application management ONLY

set -e

NAMESPACE=${1:-argowf-dev}
BRANCH=${2:-$(git branch --show-current)}
APP_NAME="homelab-mlops-demo-$(echo $NAMESPACE | sed 's/argowf-//')"

echo "🎯 Creating ArgoCD application: $APP_NAME"
echo "   Namespace: $NAMESPACE"
echo "   Branch: $BRANCH"

cat > argocd-apps/${APP_NAME}.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME
  namespace: argocd
  labels:
    environment: $(echo $NAMESPACE | sed 's/argowf-//')
    branch: $(echo $BRANCH | sed 's/[^a-zA-Z0-9-]/-/g')
spec:
  project: default
  source:
    repoURL: https://github.com/jtayl222/homelab-mlops-demo.git
    targetRevision: $BRANCH
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: $NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

kubectl apply -f argocd-apps/${APP_NAME}.yaml

echo "✅ ArgoCD application $APP_NAME created"
echo "📄 Configuration saved to: argocd-apps/${APP_NAME}.yaml"