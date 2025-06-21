import mlflow
mlflow.set_tracking_uri("http://192.168.1.85:30800")
client = mlflow.tracking.MlflowClient()
try:
    experiments = client.search_experiments()
    print(experiments)
except Exception as e:
    print(f"Error: {e}")
