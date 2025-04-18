helm install sealed-secrets-controller   sealed-secrets/sealed-secrets

kubectl -n argowf create secret generic minio-credentials   --from-literal=AWS_ACCESS_KEY_ID=minioadmin   --from-literal=AWS_SECRET_ACCESS_KEY=minioadmin   --from-literal=AWS_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000   --from-literal=AWS_DEFAULT_REGION=us-east-1   --dry-run=client -o yaml > minio-secret.yaml


kubeseal --format yaml --controller-name sealed-secrets-controller --controller-namespace default < minio-secret.yaml > sealed-minio-secret.yaml

kubectl apply -f sealed-minio-secret.yaml

## x

kubectl apply -f argo-seldon-rbac.yaml