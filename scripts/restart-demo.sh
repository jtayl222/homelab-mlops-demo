#!/bin/bash
# restart-demo.sh - MLOps Demo Restart Script with Namespace Support

set -e

# Parse arguments
NAMESPACE=${1:-argowf}
ACTION=${2:-restart}

usage() {
    echo "Usage: $0 [NAMESPACE] [ACTION]"
    echo ""
    echo "Arguments:"
    echo "  NAMESPACE    Target namespace (default: argowf)"
    echo "               - argowf (production)"
    echo "               - argowf-dev (development)"
    echo "               - argowf-dev-* (custom dev environments)"
    echo ""
    echo "  ACTION       Action to perform (default: restart)"
    echo "               - restart: Full cleanup and restart"
    echo "               - clean: Cleanup only"
    echo "               - deploy: Deploy only (no cleanup)"
    echo ""
    echo "Examples:"
    echo "  $0                           # Restart in production (argowf)"
    echo "  $0 argowf-dev               # Restart in development"
    echo "  $0 argowf-dev-alice         # Restart in Alice's dev environment"
    echo "  $0 argowf clean             # Clean production only"
    echo "  $0 argowf-dev deploy        # Deploy to dev only"
    echo ""
    exit 1
}

# Function to get port configuration for namespace
get_port_for_namespace() {
    local namespace=$1
    local environment="production"
    
    # Determine environment based on namespace
    if [[ "$namespace" != "argowf" ]]; then
        environment="development"
    fi
    
    # Get port from kustomize config
    local port=$(kubectl kustomize manifests/overlays/$environment 2>/dev/null | \
        yq eval 'select(.kind == "ConfigMap" and (.metadata.name | test(".*app-config"))) | .data.MODEL_SERVING_PORT' - 2>/dev/null)
    
    # Default fallback
    if [[ -z "$port" || "$port" == "null" ]]; then
        if [[ "$environment" == "development" ]]; then
            port="9001"
        else
            port="9000"
        fi
    fi
    
    echo "$port"
}

# Show help if requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

echo "🔄 Starting MLOps demo $ACTION procedure..."
echo "🎯 Target namespace: $NAMESPACE"

# Validate namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Error: Namespace '$NAMESPACE' does not exist"
    echo "Available namespaces:"
    kubectl get namespaces | grep -E "(argowf|NAME)"
    echo ""
    echo "Create the namespace first with:"
    echo "  kubectl create namespace $NAMESPACE"
    echo "Or use the development setup script:"
    echo "  ./scripts/setup-dev-environment.sh $NAMESPACE"
    exit 1
fi

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

# Determine environment type and ArgoCD app name
if [[ "$NAMESPACE" == "argowf" ]]; then
    ENV_TYPE="production"
    ARGOCD_APP="homelab-mlops-demo"
    APP_MANIFEST="applications/demo-iris-pipeline-app.yaml"
else
    ENV_TYPE="development"
    # Extract dev environment name (e.g., argowf-dev-alice -> alice)
    DEV_ENV_NAME=$(echo "$NAMESPACE" | sed 's/argowf-dev//' | sed 's/^-//')
    if [[ -z "$DEV_ENV_NAME" ]]; then
        DEV_ENV_NAME="dev"
    fi
    ARGOCD_APP="homelab-mlops-demo-$DEV_ENV_NAME"
    APP_MANIFEST="applications/demo-iris-pipeline-$DEV_ENV_NAME-app.yaml"
fi

echo "🎯 Environment type: $ENV_TYPE"
echo "🎯 ArgoCD app: $ARGOCD_APP"

# Cleanup function
cleanup() {
    echo "1. Cleaning up existing resources in $NAMESPACE..."
    
    # Delete ArgoCD app
    argocd app delete "$ARGOCD_APP" --cascade 2>/dev/null || echo "No ArgoCD app '$ARGOCD_APP' found"
    
    # Delete workflows
    argo delete -n "$NAMESPACE" --all 2>/dev/null || echo "No workflows found in $NAMESPACE"
    
    # Delete Seldon deployments
    kubectl delete seldondeployment --all -n "$NAMESPACE" 2>/dev/null || echo "No Seldon deployments found in $NAMESPACE"
    
    # Delete Iris-related resources
    kubectl delete all -n "$NAMESPACE" -l seldon-deployment-id=iris 2>/dev/null || echo "No Iris resources found in $NAMESPACE"
    
    # For semantic versioning, also delete versioned deployments
    kubectl delete seldondeployment -n "$NAMESPACE" --all 2>/dev/null || echo "No versioned deployments found"
    
    echo "2. Waiting for cleanup to complete..."
    sleep 10
}

# Deploy function
deploy() {
    echo "3. Recreating registry secret in $NAMESPACE..."
    kubectl create secret docker-registry ghcr-credentials \
      --docker-server=ghcr.io \
      --docker-username="$GITHUB_USERNAME" \
      --docker-password="$GITHUB_TOKEN" \
      --docker-email="$GITHUB_EMAIL" \
      -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

    echo "4. Deploying with kustomize for $NAMESPACE..."
    if [[ "$NAMESPACE" == "argowf" ]]; then
        # Production environment
        kubectl apply -k manifests/overlays/production
    else
        # Development environment
        kubectl apply -k manifests/overlays/development
    fi

    echo "5. Creating/updating ArgoCD application..."
    if [[ -f "$APP_MANIFEST" ]]; then
        kubectl apply -f "$APP_MANIFEST"
    else
        echo "⚠️  ArgoCD app manifest not found: $APP_MANIFEST"
        echo "For development environments, create it with:"
        echo "  ./scripts/create-argocd-app.sh $NAMESPACE"
    fi

    echo "6. Syncing ArgoCD..."
    sleep 5  # Give ArgoCD time to detect the app
    argocd app sync "$ARGOCD_APP" || echo "⚠️  ArgoCD sync failed - app may not exist yet"

    echo "7. Checking workflow status in $NAMESPACE..."
    # Check if ArgoCD already created the workflow
    if kubectl get workflow iris-demo -n "$NAMESPACE" >/dev/null 2>&1; then
        echo "✅ Workflow already exists (created by ArgoCD)"
        echo "Monitoring existing workflow..."
        argo get iris-demo -n "$NAMESPACE"
    else
        echo "Submitting workflow manually..."
        argo submit manifests/base/workflows/iris-workflow.yaml -n "$NAMESPACE"
    fi
}

# Execute based on action
case "$ACTION" in
    "clean")
        cleanup
        echo "✅ Cleanup complete for $NAMESPACE!"
        ;;
    "deploy")
        deploy
        echo "✅ Deploy complete for $NAMESPACE!"
        ;;
    "restart"|*)
        cleanup
        deploy
        echo "✅ Restart complete for $NAMESPACE!"
        ;;
esac

# Get dynamic port configuration
MODEL_PORT=$(get_port_for_namespace "$NAMESPACE")

echo ""
echo "🎯 Environment: $ENV_TYPE ($NAMESPACE)"
echo "📊 Monitor with:"
echo "   argocd app get $ARGOCD_APP"
echo "   argo get iris-demo -n $NAMESPACE --watch"
echo "   kubectl get pods -n $NAMESPACE"
if [[ "$NAMESPACE" != "argowf" ]]; then
    echo "   kubectl get seldondeployments -n $NAMESPACE"
fi
echo ""
echo "🔍 Quick status check:"
echo "ArgoCD Status: $(argocd app get "$ARGOCD_APP" --output json 2>/dev/null | jq -r '.status.sync.status + " / " + .status.health.status' 2>/dev/null || echo 'Check manually')"
echo "Workflow Status: $(argo get iris-demo -n "$NAMESPACE" --output json 2>/dev/null | jq -r '.status.phase' 2>/dev/null || echo 'Not found')"

# Show next steps based on environment
if [[ "$NAMESPACE" != "argowf" ]]; then
    echo ""
    echo "🎯 Development Environment Commands:"
    echo "   # Test the semantic versioned model (when ready):"
    echo "   kubectl port-forward -n $NAMESPACE svc/iris-0-2-0-default-classifier $MODEL_PORT:$MODEL_PORT &"
    echo "   curl -X POST http://localhost:$MODEL_PORT/api/v1.0/predictions -H 'Content-Type: application/json' -d '{\"data\":{\"ndarray\":[[5.1,3.5,1.4,0.2]]}}'"
    echo ""
    echo "   # Or use the makefile targets:"
    echo "   make port-forward-dev    # Port forward with correct port"
    echo "   make smoke-test-dev      # Run automated test"
    echo ""
    echo "   # Clean up when done:"
    echo "   ./scripts/cleanup-dev-environment.sh $NAMESPACE"
else
    # Production environment
    echo ""
    echo "🎯 Production Environment Commands:"
    echo "   # Test the model (when ready):"
    echo "   kubectl port-forward -n $NAMESPACE svc/iris-0-2-0-default-classifier $MODEL_PORT:$MODEL_PORT &"
    echo "   curl -X POST http://localhost:$MODEL_PORT/api/v1.0/predictions -H 'Content-Type: application/json' -d '{\"data\":{\"ndarray\":[[5.1,3.5,1.4,0.2]]}}'"
    echo ""
    echo "   # Or use the makefile targets:"
    echo "   make port-forward-prod   # Port forward with correct port"
    echo "   make smoke-test-prod     # Run automated test"
fi

echo ""
echo "📊 Configuration Summary:"
echo "   Environment: $ENV_TYPE"
echo "   Namespace: $NAMESPACE"  
echo "   Model Port: $MODEL_PORT"
echo "   ArgoCD App: $ARGOCD_APP"