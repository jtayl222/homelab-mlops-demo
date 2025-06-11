import json
import os
import requests
import semver
from datetime import datetime

def get_current_version():
    """Get the current version from Git tags or start with v0.1.0"""
    try:
        # In a real scenario, you'd query Git tags or a version registry
        # For demo, we'll simulate with a simple logic
        
        # Try to get last version from a hypothetical registry/git
        # For now, we'll use a simple file-based approach
        version_file = "/workspace/last_version.txt"
        
        if os.path.exists(version_file):
            with open(version_file, 'r') as f:
                last_version = f.read().strip()
            return last_version
        else:
            # Start with initial version
            return "0.1.0"
            
    except Exception as e:
        print(f"Warning: Could not determine current version: {e}")
        return "0.1.0"

def load_validation_results():
    """Load validation results from the validation step"""
    results_path = os.getenv("VALIDATION_RESULTS_PATH", "/workspace/validation_results.json")
    
    with open(results_path, 'r') as f:
        return json.load(f)

def determine_version_bump(validation_results, current_version):
    """Determine what type of version bump is needed"""
    
    accuracy = validation_results.get('accuracy', 0.0)
    validation_status = validation_results.get('validation_status', 'FAILED')
    
    # Parse current version
    try:
        version_info = semver.VersionInfo.parse(current_version)
    except:
        version_info = semver.VersionInfo.parse("0.1.0")
    
    print(f"Current version: {version_info}")
    print(f"Validation status: {validation_status}")
    print(f"Model accuracy: {accuracy:.4f}")
    
    # Version bump logic based on validation results
    if validation_status == "FAILED":
        print("❌ Validation failed - no version bump")
        return None
    
    # Determine bump type based on accuracy improvement
    if accuracy >= 0.99:
        # Exceptional accuracy - minor bump
        print("🚀 Exceptional accuracy (≥99%) - MINOR version bump")
        new_version = version_info.bump_minor()
    elif accuracy >= 0.95:
        # Good accuracy - patch bump
        print("✅ Good accuracy (≥95%) - PATCH version bump")
        new_version = version_info.bump_patch()
    elif accuracy >= 0.85:
        # Acceptable accuracy - patch bump
        print("✅ Acceptable accuracy (≥85%) - PATCH version bump")
        new_version = version_info.bump_patch()
    else:
        # Low accuracy - no version bump
        print("⚠️ Low accuracy (<85%) - no version bump")
        return None
    
    return str(new_version)

def create_model_metadata(validation_results, version):
    """Create comprehensive model metadata"""
    
    timestamp = datetime.utcnow().isoformat() + 'Z'
    
    metadata = {
        "model_version": version,
        "timestamp": timestamp,
        "validation_results": validation_results,
        "performance_metrics": {
            "accuracy": validation_results.get('accuracy', 0.0),
            "test_samples": validation_results.get('test_count', 0),
            "validation_status": validation_results.get('validation_status', 'UNKNOWN')
        },
        "model_info": {
            "algorithm": "RandomForestClassifier",
            "dataset": "iris",
            "target_classes": ["setosa", "versicolor", "virginica"],
            "features": ["sepal_length", "sepal_width", "petal_length", "petal_width"]
        },
        "deployment_info": {
            "container_registry": "ghcr.io/jtayl222/iris",
            "serving_framework": "FastAPI + Seldon",
            "kubernetes_ready": True
        }
    }
    
    return metadata

def save_version_info(version, metadata):
    """Save version information for downstream steps"""
    
    # Save version for workflow output
    version_path = os.getenv("OUTPUT_PATH", "/workspace/model_version.txt")
    with open(version_path, 'w') as f:
        f.write(version)
    
    # Save version tag for container tagging
    version_tag_path = os.getenv("VERSION_TAG_PATH", "/workspace/version_tag.txt")
    with open(version_tag_path, 'w') as f:
        f.write(f"v{version}")  # Add 'v' prefix for container tags
    
    # Save complete metadata
    metadata_path = "/workspace/model_metadata.json"
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    
    # Save current version for next run
    with open("/workspace/last_version.txt", 'w') as f:
        f.write(version)
    
    print(f"✅ Version information saved:")
    print(f"   Version: {version}")
    print(f"   Container Tag: v{version}")
    print(f"   Metadata: {metadata_path}")

def main():
    """Main versioning logic"""
    print("🏷️ Starting Model Versioning...")
    
    try:
        # Load validation results
        validation_results = load_validation_results()
        print(f"✅ Loaded validation results")
        
        # Get current version
        current_version = get_current_version()
        print(f"📋 Current version: {current_version}")
        
        # Determine version bump
        new_version = determine_version_bump(validation_results, current_version)
        
        if new_version is None:
            print("❌ No version bump - using current version")
            new_version = current_version
        else:
            print(f"🎯 New version: {new_version}")
        
        # Create metadata
        metadata = create_model_metadata(validation_results, new_version)
        
        # Save version info
        save_version_info(new_version, metadata)
        
        print(f"\n🎉 Model versioning completed!")
        print(f"Version: {new_version}")
        print(f"Container Tag: v{new_version}")
        
    except Exception as e:
        print(f"❌ Versioning failed: {str(e)}")
        
        # Save fallback version
        fallback_version = "0.1.0"
        with open(os.getenv("OUTPUT_PATH", "/workspace/model_version.txt"), 'w') as f:
            f.write(fallback_version)
        with open(os.getenv("VERSION_TAG_PATH", "/workspace/version_tag.txt"), 'w') as f:
            f.write(f"v{fallback_version}")
        
        exit(1)

if __name__ == "__main__":
    main()