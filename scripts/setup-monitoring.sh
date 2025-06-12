#!/bin/bash
set -e

NAMESPACE=${1:-monitoring}
INSTALL_GRAFANA_DASHBOARD=${2:-true}

echo "🔍 Setting up MLOps monitoring stack..."
echo "   Namespace: $NAMESPACE"
echo "   Install Grafana Dashboard: $INSTALL_GRAFANA_DASHBOARD"

# Check if monitoring namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "Creating monitoring namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
fi

echo ""
echo "1️⃣ Installing Prometheus Pushgateway..."

# Check if Pushgateway is already installed
if kubectl get deployment prometheus-pushgateway -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "✅ Pushgateway already exists, updating..."
    kubectl delete deployment prometheus-pushgateway -n "$NAMESPACE" --ignore-not-found
    kubectl delete service prometheus-pushgateway -n "$NAMESPACE" --ignore-not-found
fi

# Install Pushgateway
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: prometheus-pushgateway
  namespace: $NAMESPACE
  labels:
    app: prometheus-pushgateway
    component: pushgateway
spec:
  type: ClusterIP
  ports:
  - port: 9091
    targetPort: 9091
    protocol: TCP
    name: http
  selector:
    app: prometheus-pushgateway
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-pushgateway
  namespace: $NAMESPACE
  labels:
    app: prometheus-pushgateway
    component: pushgateway
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus-pushgateway
  template:
    metadata:
      labels:
        app: prometheus-pushgateway
        component: pushgateway
    spec:
      containers:
      - name: pushgateway
        image: prom/pushgateway:v1.9.0
        ports:
        - containerPort: 9091
          protocol: TCP
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /-/healthy
            port: 9091
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /-/ready
            port: 9091
          initialDelaySeconds: 5
          periodSeconds: 5
        args:
        - --web.listen-address=:9091
        - --web.telemetry-path=/metrics
        - --persistence.file=/tmp/pushgateway.db
        - --persistence.interval=5m
        - --log.level=info
        volumeMounts:
        - name: storage
          mountPath: /tmp
      volumes:
      - name: storage
        emptyDir: {}
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        fsGroup: 65534
EOF

echo ""
echo "2️⃣ Waiting for Pushgateway to be ready..."
kubectl wait --for=condition=available deployment/prometheus-pushgateway -n "$NAMESPACE" --timeout=120s

echo ""
echo "3️⃣ Configuring Prometheus to scrape Pushgateway..."

# Create ServiceMonitor for Prometheus Operator (if it exists)
if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
    cat << EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: prometheus-pushgateway
  namespace: $NAMESPACE
  labels:
    app: prometheus-pushgateway
    release: prometheus-stack
spec:
  selector:
    matchLabels:
      app: prometheus-pushgateway
  endpoints:
  - port: http
    interval: 30s
    path: /metrics
EOF
    echo "✅ ServiceMonitor created for Prometheus Operator"
else
    echo "⚠️  Prometheus Operator not found, manual Prometheus configuration needed"
fi

echo ""
echo "4️⃣ Testing Pushgateway connectivity..."
kubectl port-forward -n "$NAMESPACE" svc/prometheus-pushgateway 9091:9091 &
PF_PID=$!
sleep 5

# Test pushgateway
if curl -s http://localhost:9091/metrics > /dev/null; then
    echo "✅ Pushgateway is responding"
else
    echo "❌ Pushgateway not responding"
fi

# Kill port-forward
kill $PF_PID 2>/dev/null || true

if [ "$INSTALL_GRAFANA_DASHBOARD" = "true" ]; then
    echo ""
    echo "5️⃣ Installing Grafana Dashboard..."
    ./scripts/install-grafana-dashboard.sh
fi

echo ""
echo "🎯 Monitoring setup complete!"
echo ""
echo "📊 Access URLs:"
echo "   Pushgateway: kubectl port-forward -n $NAMESPACE svc/prometheus-pushgateway 9091:9091"
echo "   Grafana: kubectl port-forward -n $NAMESPACE svc/prometheus-stack-grafana 3000:80"
echo ""
echo "🔧 Test MLOps monitoring:"
echo "   ./scripts/test-monitoring.sh"

chmod +x scripts/setup-monitoring.sh