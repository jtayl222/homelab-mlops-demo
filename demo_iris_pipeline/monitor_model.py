#!/usr/bin/env python3
"""
Model Monitoring Script for MLOps Pipeline
Exports metrics to Prometheus for Grafana visualization
"""

import os
import json
import time
import logging
import requests  # Use requests instead of curl

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def get_environment_vars():
    """Get environment variables for monitoring"""
    return {
        'model_version': os.getenv('MODEL_VERSION', 'unknown'),
        'environment': os.getenv('NAMESPACE', 'unknown'),
        'stage': os.getenv('PIPELINE_STAGE', 'unknown'),
        'pushgateway_url': os.getenv('PUSHGATEWAY_URL', 'http://prometheus-pushgateway.monitoring.svc.cluster.local:9091')
    }

def load_validation_results():
    """Load model validation results"""
    validation_path = os.getenv('VALIDATION_RESULTS_PATH', '/workspace/validation_results.json')
    
    if not os.path.exists(validation_path):
        logger.warning(f"Validation results not found at {validation_path}")
        return {}
    
    try:
        with open(validation_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        logger.error(f"Error loading validation results: {e}")
        return {}

def export_metrics_to_pushgateway():
    """Export metrics to Prometheus Pushgateway using requests"""
    env_vars = get_environment_vars()
    validation_results = load_validation_results()
    
    if not validation_results:
        logger.warning("No validation results found, creating default metrics")
        validation_results = {
            'accuracy': 0.0,
            'precision': 0.0,
            'recall': 0.0,
            'f1_score': 0.0,
            'validation_status': 'UNKNOWN'
        }
    
    # Create metrics in Prometheus format
    metrics_data = f"""# MLOps Pipeline Metrics
# TYPE iris_model_accuracy gauge
iris_model_accuracy{{version="{env_vars['model_version']}",environment="{env_vars['environment']}"}} {validation_results.get('accuracy', 0)}

# TYPE iris_model_precision gauge  
iris_model_precision{{version="{env_vars['model_version']}",environment="{env_vars['environment']}"}} {validation_results.get('precision', 0)}

# TYPE iris_model_recall gauge
iris_model_recall{{version="{env_vars['model_version']}",environment="{env_vars['environment']}"}} {validation_results.get('recall', 0)}

# TYPE iris_model_f1_score gauge
iris_model_f1_score{{version="{env_vars['model_version']}",environment="{env_vars['environment']}"}} {validation_results.get('f1_score', 0)}

# TYPE iris_pipeline_stage_success counter
iris_pipeline_stage_success{{version="{env_vars['model_version']}",environment="{env_vars['environment']}",stage="{env_vars['stage']}"}} 1

# TYPE iris_model_deployment_timestamp gauge
iris_model_deployment_timestamp{{version="{env_vars['model_version']}",environment="{env_vars['environment']}"}} {time.time()}
"""
    
    # Push metrics using requests with timeout
    pushgateway_url = f"{env_vars['pushgateway_url']}/metrics/job/iris-mlops-pipeline/version/{env_vars['model_version']}/environment/{env_vars['environment']}/stage/{env_vars['stage']}"
    
    try:
        logger.info(f"Pushing metrics to {pushgateway_url}")
        response = requests.post(
            pushgateway_url,
            data=metrics_data,
            headers={'Content-Type': 'text/plain; version=0.0.4; charset=utf-8'},
            timeout=10  # 10 second timeout
        )
        
        if response.status_code == 200:
            logger.info("✅ Successfully pushed metrics to Pushgateway")
        else:
            logger.warning(f"⚠️ Failed to push metrics: {response.status_code} - {response.text}")
            
    except requests.exceptions.Timeout:
        logger.error("❌ Timeout pushing metrics to Pushgateway")
    except requests.exceptions.ConnectionError:
        logger.error("❌ Connection error to Pushgateway")
    except Exception as e:
        logger.error(f"❌ Error pushing metrics: {e}")

def main():
    """Main monitoring function"""
    logger.info("🔍 Starting MLOps monitoring...")
    
    env_vars = get_environment_vars()
    logger.info(f"Environment: {env_vars}")
    
    # Load data
    validation_results = load_validation_results()
    logger.info(f"Validation Results: {validation_results}")
    
    # Export metrics
    export_metrics_to_pushgateway()
    
    logger.info("✅ Monitoring completed")

if __name__ == "__main__":
    main()