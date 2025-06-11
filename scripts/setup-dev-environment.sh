#!/bin/bash
# setup-dev-environment.sh - Environment orchestration ONLY

set -e

NAMESPACE=${1:-argowf-dev}
FEATURE_BRANCH=${2:-$(git branch --show-current)}

echo "🚀 Setting up complete development environment"
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