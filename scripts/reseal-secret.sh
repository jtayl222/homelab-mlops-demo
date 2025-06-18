#!/bin/sh

kubectl get secret minio-credentials-wf -n argowf -o yaml > /tmp/minio-secret.yaml

# Prompt user before editing
echo "Please edit /tmp/minio-secret.yaml:"
echo "  • change metadata.namespace to 'iris-demo'"
echo "  • remove any ownerReferences and status sections"
read -r -p "Press Enter to open the editor..." dummy

vi /tmp/minio-secret.yaml

cat /tmp/minio-secret.yaml 

kubeseal --fetch-cert   --controller-namespace kube-system --controller-name sealed-secrets    > /tmp/pub-cert.pem

kubeseal   --format yaml   --cert /tmp/pub-cert.pem   < /tmp/minio-secret.yaml   > k8s/applications/iris-demo/base/minio-credentials-wf.yaml

kubectl apply -f k8s/applications/iris-demo/base/minio-credentials-wf.yaml