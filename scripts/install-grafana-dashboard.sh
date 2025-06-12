#!/bin/bash
set -e

NAMESPACE=${1:-monitoring}
GRAFANA_SERVICE=${2:-prometheus-stack-grafana}

echo "📊 Installing Iris MLOps Grafana Dashboard..."

# Check if Grafana is available
if ! kubectl get service "$GRAFANA_SERVICE" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Grafana service '$GRAFANA_SERVICE' not found in namespace '$NAMESPACE'"
    echo "Available services:"
    kubectl get services -n "$NAMESPACE" | grep grafana || echo "No Grafana services found"
    exit 1
fi

# Create ConfigMap with dashboard JSON
echo "Creating dashboard ConfigMap..."
kubectl create configmap iris-mlops-dashboard \
    --from-file=monitoring/iris-mlops-dashboard.json \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# Create Grafana Dashboard resource (if using Grafana Operator)
if kubectl get crd grafanadashboards.integreatly.org >/dev/null 2>&1; then
    cat << EOF | kubectl apply -f -
apiVersion: integreatly.org/v1alpha1
kind: GrafanaDashboard
metadata:
  name: iris-mlops-dashboard
  namespace: $NAMESPACE
  labels:
    app: grafana
spec:
  configMapRef:
    name: iris-mlops-dashboard
    key: iris-mlops-dashboard.json
  datasources:
  - inputName: "DS_PROMETHEUS"
    datasourceName: "Prometheus"
EOF
    echo "✅ GrafanaDashboard resource created"
else
    echo "⚠️  Grafana Operator not found"
    echo "📋 Manual dashboard import required:"
    echo "   1. kubectl port-forward -n $NAMESPACE svc/$GRAFANA_SERVICE 3000:80"
    echo "   2. Visit http://localhost:3000 (admin/prom-operator)"
    echo "   3. Import dashboard from monitoring/iris-mlops-dashboard.json"
fi

echo "✅ Dashboard installation complete"

chmod +x scripts/install-grafana-dashboard.sh