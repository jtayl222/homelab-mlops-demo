#!/bin/bash
# update-configmap.sh

# Ensure we fail fast
set -e

# Generate the updated ConfigMap YAML and save it
kubectl create configmap iris-src --from-file=demo_iris_pipeline/ --dry-run=client -o yaml > applications/iris-src-configmap.yaml

echo "ConfigMap applications/iris-src-configmap.yaml updated. Please commit and push it to GitHub."
