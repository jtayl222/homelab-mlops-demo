import mlflow, os, pickle, json
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score

mlflow.set_tracking_uri(os.environ["MLFLOW_TRACKING_URI"])  # http://mlflow.mlflow.svc:5000
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

    # save artefact for downstream image build
    os.makedirs("/output/model", exist_ok=True)
    model_path = "/output/model/model.pkl"
    print(f"Saving model to {model_path}")
    with open(model_path, "wb") as f:
        pickle.dump(clf, f)
    mlflow.log_artifacts("/output/model")

    # write a tiny JSON so the next step knows where the artefact is
    run_id = mlflow.active_run().info.run_id
    with open("/output/run_info.json", "w") as f:
        json.dump({"run_id": run_id}, f)
