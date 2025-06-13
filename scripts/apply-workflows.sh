#!/bin/bash
set -e

NAMESPACE=${1:-argowf}

echo "🚀 Applying Argo Workflows to namespace: $NAMESPACE"

# Apply all workflow manifests
kubectl apply -f manifests/workflows/ -n $NAMESPACE

echo "✅ Workflows applied successfully!"
