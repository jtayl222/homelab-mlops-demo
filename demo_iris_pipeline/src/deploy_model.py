import os
import json
import yaml
from datetime import datetime
import subprocess

def load_model_metadata():
    """Load model metadata from versioning step"""
    metadata_path = "/workspace/model_metadata.json"
    
    if os.path.exists(metadata_path):
        with open(metadata_path, 'r') as f:
            return json.load(f)
    else:
        # Fallback if metadata doesn't exist
        return {
            "model_version": os.getenv("MODEL_VERSION", "0.1.0"),
            "timestamp": datetime.utcnow().isoformat() + 'Z',
            "validation_results": {"validation_status": "UNKNOWN"}
        }

def generate_seldon_deployment(image_tag, model_version, metadata):
    """Generate SeldonDeployment manifest with versioning info"""
    
    # Get environment variables
    namespace = os.getenv('DEPLOYMENT_NAMESPACE', 'iris-demo')
    model_name = os.getenv("MODEL_NAME", "iris")
    
    # Create deployment name with version
    deployment_name = f"{model_name}-{model_version.replace('.', '-')}"
    
    seldon_deployment = {
        "apiVersion": "machinelearning.seldon.io/v1",
        "kind": "SeldonDeployment",
        "metadata": {
            "name": deployment_name,
            "namespace": namespace,
            "labels": {
                "app": model_name,
                "version": model_version,
                "managed-by": "argo-workflows"
            },
            "annotations": {
                "deployment.timestamp": metadata.get("timestamp", ""),
                "model.version": model_version,
                "model.accuracy": str(metadata.get("performance_metrics", {}).get("accuracy", "unknown")),
                "validation.status": metadata.get("validation_results", {}).get("validation_status", "unknown")
            }
        },
        "spec": {
            "name": deployment_name,
            "predictors": [
                {
                    "name": "default",
                    "replicas": 1,
                    "componentSpecs": [
                        {
                            "spec": {
                                "imagePullSecrets": [
                                    {"name": "iris-demo-ghcr"}
                                ],
                                "containers": [
                                    {
                                        "name": "classifier",
                                        "image": f"ghcr.io/jtayl222/iris:{image_tag}",
                                        "volumeMounts": [
                                            {
                                                "name": "classifier-provision-location",
                                                "mountPath": "/mnt/models"
                                            }
                                        ],
                                        "ports": [
                                            {"containerPort": 8080, "name": "http", "protocol": "TCP"},  # Change from 9000 to 8080
                                            {"containerPort": 9500, "name": "grpc", "protocol": "TCP"}
                                        ],
                                        "env": [
                                            {
                                                "name": "MODEL_VERSION",
                                                "value": model_version
                                            },
                                            {"name": "MLSERVER_HTTP_PORT", "value": "8080"}  # Change from 9000 to 8080
                                        ],
                                        "resources": {
                                            "requests": {
                                                "memory": "1Gi",
                                                "cpu": "500m"
                                            },
                                            "limits": {
                                                "memory": "2Gi",
                                                "cpu": "1"
                                            }
                                        }
                                    }
                                ],
                                "initContainers": [
                                    {
                                        "name": "classifier-model-initializer",
                                        "image": "seldonio/rclone-storage-initializer:1.17.1",
                                        "args": [
                                            "mlflow-artifacts:mlflow-artifacts/16/b3e9c966addd4b41a7409184cb0d916a/artifacts/model",  # SOURCE (update with your real path)
                                            "/mnt/models"                                   # DESTINATION
                                        ],
                                        "volumeMounts": [
                                            {
                                                "name": "classifier-provision-location",
                                                "mountPath": "/mnt/models"
                                            },
                                            {
                                                "name": "rclone-config",
                                                "mountPath": "/config/rclone",
                                                "readOnly": True
                                            }
                                        ],
                                        "env": [
                                            {
                                                "name": "RCLONE_CONFIG",
                                                "value": "/config/rclone/rclone.conf"
                                            }
                                        ],
                                        "resources": {
                                            "requests": {
                                                "memory": "100Mi"
                                            },
                                            "limits": {
                                                "memory": "1Gi"
                                            }
                                        }
                                    }
                                ],
                                "volumes": [
                                    {
                                        "name": "classifier-provision-location",
                                        "emptyDir": {}
                                    },
                                    {
                                        "name": "rclone-config",
                                        "secret": {
                                            "secretName": "rclone-config"
                                        }
                                    }
                                ]
                            }
                        }
                    ],
                    "graph": {
                        "name": "classifier",
                        "type": "MODEL",
                        "parameters": [
                            {
                                "name": "model_uri",
                                "value": "/mnt/models",
                                "type": "STRING"
                            }
                        ]
                    }
                }
            ]
        }
    }
    
    return seldon_deployment

def cleanup_old_deployments(current_version, namespace="iris-demo"):
    """Clean up old deployment versions (keep last 3)"""
    try:
        # Get all SeldonDeployments for this model
        result = subprocess.run([
            "kubectl", "get", "seldondeployments", "-n", namespace,
            "-l", "app=iris", "-o", "jsonpath={.items[*].metadata.name}"
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            deployments = result.stdout.strip().split()
            
            # Sort deployments (assuming version-based naming)
            deployments.sort()
            
            # Keep only the last 3 versions, delete older ones
            if len(deployments) > 3:
                old_deployments = deployments[:-3]
                for old_deployment in old_deployments:
                    print(f"🗑️ Cleaning up old deployment: {old_deployment}")
                    subprocess.run([
                        "kubectl", "delete", "seldondeployment", old_deployment, "-n", namespace
                    ])
                    
    except Exception as e:
        print(f"⚠️ Warning: Could not clean up old deployments: {e}")

def save_deployment_manifest(seldon_deployment):
    """Save the deployment manifest for kubectl apply"""
    output_path = "/workspace/seldon.yaml"
    
    with open(output_path, 'w') as f:
        yaml.dump(seldon_deployment, f, default_flow_style=False)
    
    print(f"✅ Seldon deployment manifest saved to {output_path}")
    return output_path

def deploy_model():
    """Deploy model using environment variables from workflow"""
    image_tag = os.environ['IMAGE_TAG']
    model_version = os.environ['MODEL_VERSION']
    namespace = os.environ.get('NAMESPACE', 'iris-demo')
    
    print(f"🚀 Deploying {image_tag} version {model_version} to {namespace}")
    
    try:
        # Load model metadata
        metadata = load_model_metadata()
        print(f"📊 Model Accuracy: {metadata.get('performance_metrics', {}).get('accuracy', 'unknown')}")
        
        # Generate deployment manifest
        seldon_deployment = generate_seldon_deployment(image_tag, model_version, metadata)
        
        # Save manifest
        manifest_path = save_deployment_manifest(seldon_deployment)
        
        # Apply deployment
        print("🎯 Applying SeldonDeployment...")
        
        result = subprocess.run([
            "kubectl", "apply", "-f", manifest_path
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ SeldonDeployment applied successfully!")
            print(result.stdout)
            
            # Clean up old deployments
            cleanup_old_deployments(model_version)
            
            # Wait for deployment to be ready
            deployment_name = f"iris-{model_version.replace('.', '-')}"
            print(f"⏳ Waiting for deployment {deployment_name} to be ready...")
            
            subprocess.run([
                "kubectl", "wait", "--for=condition=Ready", 
                f"seldondeployment/{deployment_name}",
                "-n", os.getenv("NAMESPACE", "iris-demo"),
                "--timeout=300s"
            ])
            
            print(f"🎉 Model v{model_version} deployed successfully!")
            
        else:
            print(f"❌ Deployment failed: {result.stderr}")
            exit(1)
            
    except Exception as e:
        print(f"❌ Deployment failed: {str(e)}")
        exit(1)

if __name__ == "__main__":
    deploy_model()