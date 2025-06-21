import mlflow
import mlflow.sklearn
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier

mlflow.set_tracking_uri("http://192.168.1.85:30800")
mlflow.set_experiment("iris_demo")

with mlflow.start_run() as run:
    X, y = load_iris(return_X_y=True)
    clf = RandomForestClassifier()
    clf.fit(X, y)
    mlflow.sklearn.log_model(
        clf, 
        "model", 
        registered_model_name="iris_classifier"  # <-- This registers the model!
    )
    print("Run ID:", run.info.run_id)