#!/bin/bash
set -e

NAMESPACE=${1:-argowf}

echo "📋 Updating ConfigMap iris-src in namespace: $NAMESPACE"

# Delete existing ConfigMap if it exists
kubectl delete configmap iris-src -n $NAMESPACE --ignore-not-found=true

# Create new ConfigMap from directory
kubectl create configmap iris-src \
  --from-file=demo_iris_pipeline/ \
  --namespace=$NAMESPACE

echo "✅ ConfigMap iris-src updated successfully in namespace $NAMESPACE!"

# Verify monitor_model.py is included
if kubectl get configmap iris-src -n $NAMESPACE -o yaml | grep -q "monitor_model.py:"; then
    echo "✅ monitor_model.py is included in ConfigMap"
else
    echo "❌ monitor_model.py is NOT in ConfigMap"
    exit 1
fi
