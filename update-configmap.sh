#!/bin/bash
# update-configmap.sh

set -e

kubectl create configmap iris-src \
  --from-file=serve.py=demo_iris_pipeline/serve.py \
  --from-file=train.py=demo_iris_pipeline/train.py \
  --from-file=Dockerfile=demo_iris_pipeline/Dockerfile \
  --from-file=requirements.txt=demo_iris_pipeline/requirements.txt \
  --namespace=argowf \
  --dry-run=client -o yaml | \
  grep -v "creationTimestamp" > demo_iris_pipeline/iris-src-configmap.yaml

echo "ConfigMap updated successfully!"