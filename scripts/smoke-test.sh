# Quick smoke test of deployed model
DEPLOYMENT_NAME=$(kubectl get seldondeployments -n argowf -o name | head -1 | cut -d'/' -f2)

if [ ! -z "$DEPLOYMENT_NAME" ]; then
  # Port forward and test prediction
  kubectl port-forward -n argowf svc/${DEPLOYMENT_NAME}-default 8080:8080 &
  sleep 5
  
  # Send test request
  curl -X POST http://localhost:8080/api/v1.0/predictions \
    -H "Content-Type: application/json" \
    -d '{"data": {"ndarray": [[5.1, 3.5, 1.4, 0.2]]}}' \
    && echo "✅ Model endpoint works"
  
  # Clean up port forward
  pkill -f "kubectl port-forward"
else
  echo "❌ No SeldonDeployment found"
fi
