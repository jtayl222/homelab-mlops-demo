#!/bin/bash
# setup-rbac.sh - RBAC management ONLY

set -e

SOURCE_NAMESPACE=${1:-argowf}
TARGET_NAMESPACE=${2:-argowf-dev}

echo "🔐 Setting up RBAC for namespace: $TARGET_NAMESPACE"
echo "   Source: $SOURCE_NAMESPACE"

# Create service account
echo "👤 Creating service account..."
kubectl create serviceaccount argo-workflow -n $TARGET_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Copy all roles from source
echo "📋 Copying Roles from $SOURCE_NAMESPACE to $TARGET_NAMESPACE..."
kubectl get roles -n $SOURCE_NAMESPACE -o yaml | \
  sed "s/namespace: $SOURCE_NAMESPACE/namespace: $TARGET_NAMESPACE/g" | \
  kubectl apply -f -

# Copy all role bindings from source
echo "📋 Copying RoleBindings from $SOURCE_NAMESPACE to $TARGET_NAMESPACE..."
kubectl get rolebindings -n $SOURCE_NAMESPACE -o yaml | \
  sed "s/namespace: $SOURCE_NAMESPACE/namespace: $TARGET_NAMESPACE/g" | \
  kubectl apply -f -

echo "✅ RBAC setup complete for $TARGET_NAMESPACE"

# Verification
echo ""
echo "📊 RBAC Summary:"
echo "Roles: $(kubectl get roles -n $TARGET_NAMESPACE --no-headers | wc -l)"
echo "RoleBindings: $(kubectl get rolebindings -n $TARGET_NAMESPACE --no-headers | wc -l)"
echo "ServiceAccounts: $(kubectl get serviceaccounts -n $TARGET_NAMESPACE | grep argo-workflow | wc -l)"