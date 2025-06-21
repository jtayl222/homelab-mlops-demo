# Create simple_test.py
import requests
import json

# Test MLflow endpoints
base_url = "http://192.168.1.85:30800"

# Test health
response = requests.get(f"{base_url}/health")
print(f"Health: {response.text}")

# Test version
#response = requests.get(f"{base_url}/version")
#print(f"Version: {response.json()}")

# Test experiments list
response = requests.get(f"{base_url}/api/2.0/mlflow/experiments/list")
print(f"Experiments: {response.json()}")

# Test Model Registry
response = requests.get(f"{base_url}/api/2.0/mlflow/registered-models/list")
print(f"Registered Models: {response.json()}")

# Create a registered model
model_data = {
    "name": "simple-test-model",
    "description": "Simple test model via API"
}

response = requests.post(
    f"{base_url}/api/2.0/mlflow/registered-models/create",
    headers={"Content-Type": "application/json"},
    data=json.dumps(model_data)
)

if response.status_code == 200:
    print(f"✅ Model created: {response.json()}")
else:
    print(f"❌ Model creation failed: {response.status_code} - {response.text}")
