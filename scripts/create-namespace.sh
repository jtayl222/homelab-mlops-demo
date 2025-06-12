#!/bin/bash
# create-namespace.sh - Namespace management ONLY

set -e

NAMESPACE=${1:-argowf-dev}

echo "📁 Creating namespace: $NAMESPACE"

# Create namespace if it doesn't exist
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Add labels for organization
kubectl label namespace $NAMESPACE \
  app.kubernetes.io/name=homelab-mlops \
  app.kubernetes.io/component=development \
  environment=development \
  --overwrite

echo "✅ Namespace $NAMESPACE created and labeled"

# Show namespace info
kubectl get namespace $NAMESPACE --show-labels

echo ""
echo "1.5️⃣ Creating workdir PVC..."

# Delete existing PVC if it has conflicts
if kubectl get pvc workdir -n $NAMESPACE >/dev/null 2>&1; then
  echo "PVC exists, checking for conflicts..."
  # Force delete and recreate to avoid version conflicts
  kubectl delete pvc workdir -n $NAMESPACE --force --grace-period=0 2>/dev/null || true
  sleep 5
fi

# Create fresh PVC
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: workdir
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: shared-nfs
EOF

echo "✅ workdir PVC created in $NAMESPACE"