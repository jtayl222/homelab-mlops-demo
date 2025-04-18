
kubectl -n argowf \
  create configmap iris-src \
  --from-file=Dockerfile=demo_iris_pipeline/Dockerfile \
  --from-file=requirements.txt=demo_iris_pipeline/requirements.txt \
  --from-file=train.py=demo_iris_pipeline/src/train.py \
  --from-file=serve.py=demo_iris_pipeline/serve.py \
  --dry-run=client -o yaml | kubectl apply -f -