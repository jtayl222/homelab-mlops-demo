#!/bin/bash
# verify-environment.sh - Environment verification ONLY

set -e

NAMESPACE=${1:-argowf-dev}

echo "🔍 Verifying environment: $NAMESPACE"

# Check namespace
echo "📁 Namespace:"
kubectl get namespace $NAMESPACE --show-labels

# Check service accounts
echo ""
echo "👤 Service Accounts:"
kubectl get serviceaccounts -n $NAMESPACE | grep argo-workflow || echo "❌ argo-workflow service account missing"

# Check RBAC
echo ""
echo "🔐 RBAC:"
ROLES=$(kubectl get roles -n $NAMESPACE --no-headers | wc -l)
ROLEBINDINGS=$(kubectl get rolebindings -n $NAMESPACE --no-headers | wc -l)
echo "   Roles: $ROLES"
echo "   RoleBindings: $ROLEBINDINGS"

if [ $ROLES -eq 0 ] || [ $ROLEBINDINGS -eq 0 ]; then
  echo "❌ RBAC not properly configured"
else
  echo "✅ RBAC configured"
fi

# Check secrets
echo ""
echo "🔑 Secrets:"
kubectl get secrets -n $NAMESPACE | grep -E "(minio|ghcr)" || echo "❌ Required secrets missing"

# Check ConfigMaps
echo ""
echo "📋 ConfigMaps:"
kubectl get configmaps -n $NAMESPACE | grep iris-src || echo "❌ iris-src ConfigMap missing"

# Overall status
echo ""
echo "📊 Environment Status:"
CHECKS=0
PASSED=0

# Check each component
if kubectl get serviceaccount argo-workflow -n $NAMESPACE >/dev/null 2>&1; then
  PASSED=$((PASSED + 1))
fi
CHECKS=$((CHECKS + 1))

if [ $ROLES -gt 0 ] && [ $ROLEBINDINGS -gt 0 ]; then
  PASSED=$((PASSED + 1))
fi
CHECKS=$((CHECKS + 1))

if kubectl get secret minio-credentials-wf -n $NAMESPACE >/dev/null 2>&1; then
  PASSED=$((PASSED + 1))
fi
CHECKS=$((CHECKS + 1))

if kubectl get configmap iris-src -n $NAMESPACE >/dev/null 2>&1; then
  PASSED=$((PASSED + 1))
fi
CHECKS=$((CHECKS + 1))

echo "   Passed: $PASSED/$CHECKS checks"

if [ $PASSED -eq $CHECKS ]; then
  echo "✅ Environment ready for workflows!"
  exit 0
else
  echo "❌ Environment not ready - see issues above"
  exit 1
fi