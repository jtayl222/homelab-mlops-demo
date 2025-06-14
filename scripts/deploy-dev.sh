#!/bin/bash
set -e

echo "Deploying to development environment..."
kubectl apply -k manifests/overlays/development

# Validate first
./scripts/validate-kustomize.sh

echo "Waiting for deployment..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=iris-demo -n argowf-dev --timeout=300s

echo "Development deployment complete!"
echo "Port forward with:"
echo "  kubectl port-forward -n argowf-dev svc/dev-iris-0-2-0-default-classifier 9001:9001"
