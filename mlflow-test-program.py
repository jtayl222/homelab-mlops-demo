import os
import mlflow
from mlflow.exceptions import MlflowException
import random
import time

# --- Configuration ---
# Ensure these environment variables are set in your shell before running this script:
# export MLFLOW_TRACKING_USERNAME="mlflow"
# export MLFLOW_TRACKING_PASSWORD="my-secure-mlflow-tracking-password"
# (Replace with your actual admin password)

MLFLOW_TRACKING_URI = "http://192.168.1.85:30800" # Your external NodePort URL

# Set MLflow tracking URI
os.environ["MLFLOW_TRACKING_URI"] = MLFLOW_TRACKING_URI

print(f"Attempting to connect to MLflow Tracking Server at: {MLFLOW_TRACKING_URI}")
print(f"Using username: {os.getenv('MLFLOW_TRACKING_USERNAME')}")

try:
    # --- Test 1: List experiments (Initial connection test) ---
    print("\n--- Test 1: Listing existing experiments ---")
    experiments = mlflow.search_experiments()
    if experiments:
        print("Existing Experiments:")
        for exp in experiments:
            print(f"  - Name: {exp.name}, ID: {exp.experiment_id}, Lifecycle: {exp.lifecycle_stage}")
    else:
        print("No experiments found or unable to list experiments initially.")

    # --- Test 2: Create a new experiment and log a run ---
    experiment_name = f"MyTestExperiment-{int(time.time())}"
    print(f"\n--- Test 2: Creating a new experiment: '{experiment_name}' ---")
    new_experiment_id = mlflow.create_experiment(experiment_name)
    print(f"Created experiment with ID: {new_experiment_id}")

    print(f"\n--- Test 2.1: Logging a run in '{experiment_name}' ---")
    with mlflow.start_run(experiment_id=new_experiment_id, run_name="test_run") as run:
        print(f"Started run with ID: {run.info.run_id}")
        mlflow.log_param("param1", "valueA")
        mlflow.log_metric("metric1", random.random())
        mlflow.log_metric("metric2", random.randint(1, 100))
        print("Logged params and metrics.")

        # Save a dummy artifact
        artifact_path = "output.txt"
        with open(artifact_path, "w") as f:
            f.write("This is a test artifact.")
        mlflow.log_artifact(artifact_path)
        print(f"Logged artifact: {artifact_path}")
        os.remove(artifact_path) # Clean up dummy file

    print("Run completed successfully.")

    # --- Test 3: Re-list experiments to see the new one ---
    print("\n--- Test 3: Re-listing experiments ---")
    experiments = mlflow.search_experiments()
    print("All Experiments (after creating new one):")
    for exp in experiments:
        print(f"  - Name: {exp.name}, ID: {exp.experiment_id}, Lifecycle: {exp.lifecycle_stage}")

    print("\nMLflow client tests completed successfully!")

except MlflowException as e:
    print(f"\nMLflow Error: {e}")
    print("Please check your MLFLOW_TRACKING_URI, authentication credentials, "
          "and ensure the MLflow server is running and accessible.")
except Exception as e:
    print(f"\nAn unexpected error occurred: {e}")
    print("Ensure all required Python packages are installed (mlflow, psycopg2-binary, boto3).")
