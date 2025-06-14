#!/bin/bash

NAMESPACE=${1:-argowf-dev}

if [[ "$NAMESPACE" == "argowf" ]]; then
    OVERLAY="production"
    APP_NAME="homelab-mlops-demo"
else
    OVERLAY="development"
    DEV_ENV_NAME=$(echo "$NAMESPACE" | sed 's/argowf-dev//' | sed 's/^-//')
    if [[ -z "$DEV_ENV_NAME" ]]; then
        DEV_ENV_NAME="dev"
    fi
    APP_NAME="homelab-mlops-demo-$DEV_ENV_NAME"
fi

echo "Creating ArgoCD app: $APP_NAME for namespace: $NAMESPACE"

cat > /tmp/argocd-app-$APP_NAME.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/jtayl222/homelab-mlops-demo.git
    targetRevision: HEAD
    path: manifests/overlays/$OVERLAY
  destination:
    server: https://kubernetes.default.svc
    namespace: $NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

kubectl apply -f /tmp/argocd-app-$APP_NAME.yaml
rm -f /tmp/argocd-app-$APP_NAME.yaml

echo "✅ ArgoCD app created successfully!"
echo "Monitor with: argocd app get $APP_NAME"
