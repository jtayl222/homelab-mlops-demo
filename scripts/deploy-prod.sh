#!/bin/bash
set -e

echo "Deploying to production environment..."
kubectl apply -k manifests/overlays/production

echo "Waiting for deployment..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=iris-demo -n argowf --timeout=300s

echo "Production deployment complete!"
