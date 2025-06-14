import mlflow, os, pickle, json
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
import boto3
from botocore.client import Config

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

    # Save model to /output/model/ (for workflow persistence)
    os.makedirs("/output/model", exist_ok=True)
    model_path = "/output/model/model.pkl"
    print(f"Saving model to {model_path}")
    with open(model_path, "wb") as f:
        pickle.dump(clf, f)
    mlflow.log_artifacts("/output/model")

    # Save model to MinIO
    try:
        s3_client = boto3.client(
            's3',
            endpoint_url=os.getenv('AWS_ENDPOINT_URL'),
            aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),  # Fixed parameter name
            aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY'),  # Fixed parameter name
            config=Config(signature_version='s3v4'),
            region_name=os.getenv('AWS_DEFAULT_REGION', 'us-east-1')
        )

        # Get model version from environment or generate one
        model_version = os.getenv("MODEL_VERSION", "0.1.0")
        
        # Create bucket if it doesn't exist
        try:
            s3_client.head_bucket(Bucket='models')
        except:
            s3_client.create_bucket(Bucket='models')
            print("Created 'models' bucket in MinIO")

        # Upload model to MinIO (use correct local path)
        model_key = f"iris/{model_version}/model.pkl"
        s3_client.upload_file(model_path, 'models', model_key)  # Use model_path instead of /workspace/model.pkl
        print(f"Model uploaded to MinIO: s3://models/{model_key}")
        
    except Exception as e:
        print(f"Warning: Failed to upload to MinIO: {e}")
        print("Continuing with local model storage only...")

    # Write run info
    run_id = mlflow.active_run().info.run_id
    with open("/output/run_info.json", "w") as f:
        json.dump({"run_id": run_id, "model_version": model_version}, f)
    
    print("Training complete with accuracy:", acc)
