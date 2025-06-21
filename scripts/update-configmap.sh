#!/bin/bash
set -e

NAMESPACE=${1:-iris-demo}

echo "📋 Generating ConfigMap iris-src for namespace: $NAMESPACE"

# Ensure target directory exists
mkdir -p k8s/applications/iris-demo/base

# Generate ConfigMap YAML (GitOps-First) - source code only
kubectl create configmap iris-src \
  --from-file=demo_iris_pipeline/src/ \
  --namespace=$NAMESPACE \
  --dry-run=client -o yaml | \
  grep -v "creationTimestamp" > k8s/applications/iris-demo/base/configmap.yaml

echo "✅ ConfigMap YAML generated: k8s/applications/iris-demo/base/configmap.yaml"

