#!/bin/bash
# Get configuration values from kustomize

ENVIRONMENT=${1:-production}
CONFIG_KEY=${2:-MODEL_SERVING_PORT}

# Extract config from kustomize output
kubectl kustomize manifests/overlays/$ENVIRONMENT | \
  yq eval "select(.kind == \"ConfigMap\" and (.metadata.name | test(\".*app-config\"))) | .data.$CONFIG_KEY" -
