#!/bin/bash
set -e

NAMESPACE=${1:-argowf}

echo "📋 Generating ConfigMap iris-src for namespace: $NAMESPACE"

# Ensure manifests directory exists
mkdir -p manifests/configmaps

# Generate ConfigMap YAML (GitOps-First) - source code only
kubectl create configmap iris-src \
  --from-file=demo_iris_pipeline/src/ \
  --namespace=$NAMESPACE \
  --dry-run=client -o yaml | \
  grep -v "creationTimestamp" > manifests/configmaps/iris-src-configmap.yaml

echo "✅ ConfigMap YAML generated: manifests/configmaps/iris-src-configmap.yaml"

# Apply the ConfigMap from the generated file
kubectl apply -f manifests/configmaps/iris-src-configmap.yaml

echo "✅ ConfigMap iris-src applied successfully in namespace $NAMESPACE!"

echo "💡 GitOps: Commit manifests/configmaps/iris-src-configmap.yaml to Git"
