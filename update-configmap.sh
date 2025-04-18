#!/bin/bash
# update-configmap.sh

set -e

kubectl create configmap iris-src \
  --from-file=serve.py=demo_iris_pipeline/serve.py \
  --from-file=train.py=demo_iris_pipeline/train.py \
  --from-file=requirements.txt=demo_iris_pipeline/requirements.txt \
  --from-file=Dockerfile=demo_iris_pipeline/Dockerfile \
  --dry-run=client -o yaml > applications/iris-src-configmap.yaml

echo "✅ ConfigMap regenerated at applications/iris-src-configmap.yaml"
