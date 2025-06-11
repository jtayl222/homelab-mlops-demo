#!/bin/bash
# update-configmap.sh - ConfigMap management ONLY

set -e

NAMESPACE=${1:-argowf}

echo "📋 Updating ConfigMap iris-src in namespace: $NAMESPACE"

# Generate ConfigMap for the specified namespace
kubectl create configmap iris-src \
  --from-file=serve.py=demo_iris_pipeline/serve.py \
  --from-file=train.py=demo_iris_pipeline/train.py \
  --from-file=test_model.py=demo_iris_pipeline/test_model.py \
  --from-file=version_model.py=demo_iris_pipeline/version_model.py \
  --from-file=deploy_model.py=demo_iris_pipeline/deploy_model.py \
  --from-file=Dockerfile=demo_iris_pipeline/Dockerfile \
  --from-file=requirements.txt=demo_iris_pipeline/requirements.txt \
  --namespace=$NAMESPACE \
  --dry-run=client -o yaml | \
  grep -v "creationTimestamp" > demo_iris_pipeline/iris-src-configmap-${NAMESPACE}.yaml

# Apply the ConfigMap
kubectl apply -f demo_iris_pipeline/iris-src-configmap-${NAMESPACE}.yaml

echo "✅ ConfigMap iris-src updated successfully in namespace $NAMESPACE!"