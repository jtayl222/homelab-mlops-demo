#!/bin/bash
set -e

NAMESPACE=${1:-argowf-dev}
ENVIRONMENT=${2:-development}

# Get deployment name and port from kustomize
DEPLOYMENT_NAME=$(kubectl kustomize manifests/overlays/$ENVIRONMENT | \
  yq eval 'select(.kind == "SeldonDeployment") | .metadata.name' -)

MODEL_PORT=$(kubectl kustomize manifests/overlays/$ENVIRONMENT | \
  yq eval 'select(.metadata.name == "app-config") | .data.MODEL_SERVING_PORT' -)

echo "Running smoke test for $DEPLOYMENT_NAME on port $MODEL_PORT..."

# Port forward in background
kubectl port-forward -n $NAMESPACE svc/${DEPLOYMENT_NAME}-default $MODEL_PORT:$MODEL_PORT &
PF_PID=$!

# Wait for port forward
sleep 5

# Test prediction
curl -X POST http://localhost:$MODEL_PORT/api/v1.0/predictions \
  -H 'Content-Type: application/json' \
  -d '{"data":{"ndarray":[[5.1,3.5,1.4,0.2]]}}' \
  --max-time 30

# Clean up
kill $PF_PID 2>/dev/null || true

echo "Smoke test completed successfully!"
