#!/bin/bash
# restart-demo.sh

set -e

echo "🔄 Starting MLOps demo restart procedure..."

# Check environment variables
echo "0. Checking environment variables..."
if [[ -z "$GITHUB_USERNAME" || -z "$GITHUB_TOKEN" || -z "$GITHUB_EMAIL" ]]; then
    echo "❌ Error: Required environment variables not set."
    echo "Please set the following environment variables:"
    echo "  export GITHUB_USERNAME='your-github-username'"
    echo "  export GITHUB_TOKEN='ghp_your_token_here'"
    echo "  export GITHUB_EMAIL='your-email@example.com'"
    echo ""
    echo "Current values:"
    echo "  GITHUB_USERNAME: ${GITHUB_USERNAME:-'<not set>'}"
    echo "  GITHUB_TOKEN: ${GITHUB_TOKEN:+<set>}${GITHUB_TOKEN:-'<not set>'}"
    echo "  GITHUB_EMAIL: ${GITHUB_EMAIL:-'<not set>'}"
    exit 1
fi

# Validate token format
if [[ ! "$GITHUB_TOKEN" =~ ^ghp_ ]]; then
    echo "⚠️  Warning: GITHUB_TOKEN doesn't start with 'ghp_' - this may not be a valid GitHub Personal Access Token"
    echo "Expected format: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✅ Environment variables are set:"
echo "  GITHUB_USERNAME: $GITHUB_USERNAME"
echo "  GITHUB_TOKEN: ${GITHUB_TOKEN:0:7}..."
echo "  GITHUB_EMAIL: $GITHUB_EMAIL"

# Cleanup
echo "1. Cleaning up existing resources..."
argocd app delete homelab-mlops-demo --cascade 2>/dev/null || echo "No ArgoCD app found"
argo delete -n argowf --all 2>/dev/null || echo "No workflows found"
kubectl delete seldondeployment --all -n argowf 2>/dev/null || echo "No Seldon deployments found"
kubectl delete all -n argowf -l seldon-deployment-id=iris 2>/dev/null || echo "No Iris resources found"

# Wait for cleanup
echo "2. Waiting for cleanup to complete..."
sleep 10

# Recreate
echo "3. Recreating registry secret..."
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username="$GITHUB_USERNAME" \
  --docker-password="$GITHUB_TOKEN" \
  --docker-email="$GITHUB_EMAIL" \
  -n argowf --dry-run=client -o yaml | kubectl apply -f -

echo "4. Regenerating ConfigMap..."
./update-configmap.sh
kubectl apply -f demo_iris_pipeline/iris-src-configmap.yaml

echo "5. Applying updated workflow definition..."
kubectl apply -f demo_iris_pipeline/workflow.yaml

echo "6. Recreating ArgoCD application..."
kubectl apply -f applications/demo-iris-pipeline-app.yaml

echo "7. Syncing ArgoCD..."
sleep 5  # Give ArgoCD time to detect the app
argocd app sync homelab-mlops-demo

echo "8. Checking workflow status..."
# Check if ArgoCD already created the workflow
if kubectl get workflow iris-demo -n argowf >/dev/null 2>&1; then
    echo "✅ Workflow already exists (created by ArgoCD)"
    echo "Monitoring existing workflow..."
    argo get iris-demo -n argowf
else
    echo "Submitting workflow manually..."
    argo submit demo_iris_pipeline/workflow.yaml -n argowf
fi

echo ""
echo "✅ Restart complete! Monitor with:"
echo "   argocd app get homelab-mlops-demo"
echo "   argo get iris-demo -n argowf --watch"
echo "   kubectl get pods -n argowf -l seldon-deployment-id=iris"
echo ""
echo "🔍 Quick status check:"
echo "ArgoCD Status: $(argocd app get homelab-mlops-demo --output json 2>/dev/null | jq -r '.status.sync.status + " / " + .status.health.status' 2>/dev/null || echo 'Check manually')"
echo "Workflow Status: $(argo get iris-demo -n argowf --output json 2>/dev/null | jq -r '.status.phase' 2>/dev/null || echo 'Not found')"