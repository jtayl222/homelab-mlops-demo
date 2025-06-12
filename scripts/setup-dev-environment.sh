#!/bin/bash
# setup-dev-environment.sh - Environment orchestration ONLY

set -e

NAMESPACE=${1:-argowf-dev}
FEATURE_BRANCH=${2:-$(git branch --show-current)}

echo "🚀 Setting up complete development environment"
echo "   Namespace: $NAMESPACE"
echo "   Feature Branch: $FEATURE_BRANCH"

# Use individual scripts with clear separation
echo ""
echo "1️⃣ Creating namespace..."
./scripts/create-namespace.sh $NAMESPACE

echo ""
echo "2️⃣ Setting up RBAC..."
./scripts/setup-rbac.sh argowf $NAMESPACE

echo ""
echo "3️⃣ Copying secrets..."
./scripts/copy-secrets.sh argowf $NAMESPACE

echo ""
echo "4️⃣ Updating ConfigMap..."
./scripts/update-configmap.sh $NAMESPACE

echo ""
echo "5️⃣ Creating ArgoCD application..."
./scripts/create-argocd-app.sh $NAMESPACE $FEATURE_BRANCH

echo ""
echo "6️⃣ Verifying environment..."
./scripts/verify-environment.sh $NAMESPACE

echo ""
echo "7️⃣ Setting up monitoring infrastructure..."
if ! kubectl get deployment prometheus-pushgateway -n monitoring >/dev/null 2>&1; then
    echo "Installing Prometheus Pushgateway..."
    ./scripts/setup-monitoring.sh monitoring false
else
    echo "✅ Monitoring infrastructure already exists"
fi

echo ""
echo "8️⃣ Testing monitoring connectivity..."
./scripts/test-monitoring.sh monitoring $NAMESPACE

echo ""
echo "🎯 Development environment with monitoring setup complete!"
echo ""
echo "📊 Monitoring URLs:"
echo "   Pushgateway: kubectl port-forward -n monitoring svc/prometheus-pushgateway 9091:9091"
echo "   Prometheus: kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090"
echo "   Grafana: kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80"