#!/bin/bash
# cleanup-dev-environment.sh - Cleanup management ONLY

set -e

NAMESPACE=${1:-argowf-dev}
APP_NAME="homelab-mlops-demo-$(echo $NAMESPACE | sed 's/argowf-//')"

echo "🧹 Cleaning up development environment: $NAMESPACE"

# Delete ArgoCD application
echo "🎯 Deleting ArgoCD application..."
if argocd app get $APP_NAME >/dev/null 2>&1; then
  argocd app delete $APP_NAME --cascade
  echo "✅ ArgoCD application deleted"
else
  echo "ℹ️  ArgoCD application not found"
fi

# Delete namespace (this removes everything in it)
echo "📁 Deleting namespace..."
kubectl delete namespace $NAMESPACE

# Remove ArgoCD app file
echo "📄 Removing ArgoCD app file..."
rm -f argocd-apps/${APP_NAME}.yaml

echo "✅ Development environment $NAMESPACE cleaned up completely"