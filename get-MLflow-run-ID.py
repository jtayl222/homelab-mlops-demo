import mlflow
client = mlflow.tracking.MlflowClient()
model = client.get_registered_model("iris_classifier")
for mv in client.search_model_versions("name='iris_classifier'"):
    if mv.current_stage == "Production":
        print("Run ID:", mv.run_id)
        print("Source:", mv.source)