# Handle model preparation for kaniko build
import os
import json
import pickle
import mlflow.sklearn

def prepare_model_for_build():
    """Download model from MLflow and prepare for container build"""
    # Load model info from training step
    with open('/output/model_info.json', 'r') as f:
        model_info = json.load(f)
    
    # Download model from MLflow
    model = mlflow.sklearn.load_model(model_info['model_uri'])
    
    # Save for container
    os.makedirs('model', exist_ok=True)
    with open('model/model.pkl', 'wb') as f:
        pickle.dump(model, f)
    
    print("✅ Model prepared for container build")

if __name__ == "__main__":
    prepare_model_for_build()