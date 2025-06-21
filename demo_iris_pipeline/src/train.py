import mlflow, os, pickle, json
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
import mlflow.sklearn

mlflow.set_tracking_uri(os.environ["MLFLOW_TRACKING_URI"])
mlflow.set_experiment("iris_demo")

with mlflow.start_run():
    X, y = load_iris(return_X_y=True)
    X_tr, X_te, y_tr, y_te = train_test_split(X, y, test_size=0.2, random_state=42)

    n_estimators = int(os.getenv("N_ESTIMATORS", 100))
    clf = RandomForestClassifier(n_estimators=n_estimators, random_state=42)
    clf.fit(X_tr, y_tr)

    acc = accuracy_score(y_te, clf.predict(X_te))
    mlflow.log_param("n_estimators", n_estimators)
    mlflow.log_metric("accuracy", acc)

    # Log model to MLflow with sklearn flavor
    model_info = mlflow.sklearn.log_model(
        clf, 
        "model",
        registered_model_name="iris_classifier"
    )
    
    # Register the model version
    version = os.getenv("MODEL_VERSION", "0.2.0")
    client = mlflow.tracking.MlflowClient()
    model_version = client.create_model_version(
        name="iris_classifier",
        source=model_info.model_uri,
        run_id=mlflow.active_run().info.run_id
    )
    
    # Transition to Production
    client.transition_model_version_stage(
        name="iris_classifier",
        version=model_version.version,
        stage="Production"
    )

    # Write model info for deployment step
    with open("/output/model_info.json", "w") as f:
        json.dump({
            "model_name": "iris_classifier",
            "model_version": model_version.version,
            "model_uri": model_info.model_uri,
            "accuracy": acc
        }, f)
    
    print(f"Model registered as iris_classifier v{model_version.version} with accuracy:", acc)
