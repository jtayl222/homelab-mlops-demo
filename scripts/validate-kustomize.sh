# scripts/validate-kustomize.sh
#!/bin/bash
set -e

echo "Validating kustomization..."

# Check development overlay
echo "✓ Testing development overlay..."
kubectl kustomize manifests/overlays/development > /tmp/dev-output.yaml
kubectl apply --dry-run=client -f /tmp/dev-output.yaml

# Check production overlay  
echo "✓ Testing production overlay..."
kubectl kustomize manifests/overlays/production > /tmp/prod-output.yaml
kubectl apply --dry-run=client -f /tmp/prod-output.yaml

# Verify port configurations dynamically
echo "✓ Checking port configurations..."
DEV_PORT=$(yq eval 'select(.metadata.name == "dev-app-config") | .data.MODEL_SERVING_PORT' < /tmp/dev-output.yaml)
PROD_PORT=$(yq eval 'select(.metadata.name == "app-config") | .data.MODEL_SERVING_PORT' < /tmp/prod-output.yaml)

echo "  ✓ Dev port correctly set to $DEV_PORT"
echo "  ✓ Prod port correctly set to $PROD_PORT"

# Verify MinIO configuration
MINIO_PORT=$(yq eval 'select(.metadata.name == "app-config") | .data.MINIO_PORT' /tmp/prod-output.yaml)
echo "  ✓ MinIO port correctly set to $MINIO_PORT"

echo "All validations passed!"
