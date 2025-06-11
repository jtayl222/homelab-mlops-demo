#!/bin/bash
set -e

NAMESPACE=${1:-argowf-dev}

echo "🔐 Setting up complete RBAC for namespace: $NAMESPACE"

# 1. Copy all roles from production
echo "📋 Copying Roles from argowf to $NAMESPACE..."
kubectl get roles -n argowf -o yaml | \
  sed "s/namespace: argowf/namespace: $NAMESPACE/g" | \
  kubectl apply -f -

# 2. Copy all role bindings from production
echo "📋 Copying RoleBindings from argowf to $NAMESPACE..."
kubectl get rolebindings -n argowf -o yaml | \
  sed "s/namespace: argowf/namespace: $NAMESPACE/g" | \
  kubectl apply -f -

# 3. Create service account if it doesn't exist
echo "👤 Creating service account..."
kubectl create serviceaccount argo-workflow -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# 4. Verify setup
echo ""
echo "✅ RBAC Setup Complete! Summary:"
echo "Roles in $NAMESPACE:"
kubectl get roles -n $NAMESPACE

echo ""
echo "RoleBindings in $NAMESPACE:"
kubectl get rolebindings -n $NAMESPACE

echo ""
echo "ServiceAccount in $NAMESPACE:"
kubectl get serviceaccounts -n $NAMESPACE | grep argo-workflow

echo ""
echo "🎯 Namespace $NAMESPACE is ready for Argo Workflows!"
