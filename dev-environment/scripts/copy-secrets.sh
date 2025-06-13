#!/bin/bash
# copy-secrets.sh - Secret management ONLY

set -e

SOURCE_NAMESPACE=${1:-argowf}
TARGET_NAMESPACE=${2:-argowf-dev}

echo "🔑 Copying secrets from $SOURCE_NAMESPACE to $TARGET_NAMESPACE"

copy_secret() {
  local secret_name=$1
  local source_ns=$2
  local target_ns=$3
  
  if kubectl get secret $secret_name -n $source_ns >/dev/null 2>&1; then
    echo "📋 Copying $secret_name..."
    kubectl get secret $secret_name -n $source_ns -o yaml | \
      sed "s/namespace: $source_ns/namespace: $target_ns/" | \
      sed '/ownerReferences:/,/uid: .*/d' | \
      sed '/resourceVersion:/d' | \
      sed '/uid:/d' | \
      sed '/creationTimestamp:/d' | \
      kubectl apply -f -
    echo "✅ $secret_name copied successfully"
  else
    echo "⚠️ Warning: $secret_name not found in $source_ns namespace"
  fi
}

# Copy required secrets
copy_secret "minio-credentials-wf" $SOURCE_NAMESPACE $TARGET_NAMESPACE
copy_secret "ghcr-credentials" $SOURCE_NAMESPACE $TARGET_NAMESPACE

echo "✅ Secret copying complete!"