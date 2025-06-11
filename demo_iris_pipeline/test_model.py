import pickle
import numpy as np
import json
import os
from sklearn.datasets import load_iris
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import train_test_split

def load_model(model_path="/model/model.pkl"):
    """Load the trained model"""
    with open(model_path, "rb") as f:
        return pickle.load(f)

def load_test_data():
    """Load and split iris dataset for testing"""
    X, y = load_iris(return_X_y=True)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.3, random_state=42, stratify=y
    )
    return X_test, y_test

def validate_model_accuracy(model, X_test, y_test, min_accuracy=0.85):
    """Test model accuracy meets minimum threshold"""
    predictions = model.predict(X_test)
    accuracy = accuracy_score(y_test, predictions)
    
    print(f"Model Accuracy: {accuracy:.4f}")
    print(f"Required Minimum: {min_accuracy}")
    
    if accuracy < min_accuracy:
        raise ValueError(f"Model accuracy {accuracy:.4f} below threshold {min_accuracy}")
    
    return accuracy, predictions

def validate_model_predictions(model, X_test):
    """Test model prediction format and types"""
    predictions = model.predict(X_test)
    
    # Check prediction shape
    assert len(predictions) == len(X_test), "Prediction count mismatch"
    
    # Check prediction values are valid class labels (0, 1, 2 for iris)
    unique_preds = np.unique(predictions)
    assert all(pred in [0, 1, 2] for pred in unique_preds), "Invalid prediction classes"
    
    # Check no NaN or infinite values
    assert not np.any(np.isnan(predictions)), "NaN values in predictions"
    assert not np.any(np.isinf(predictions)), "Infinite values in predictions"
    
    print("✅ Model prediction validation passed")
    return True

def validate_model_performance(model, X_test, y_test):
    """Comprehensive model performance validation"""
    predictions = model.predict(X_test)
    
    # Generate classification report
    report = classification_report(y_test, predictions, output_dict=True)
    conf_matrix = confusion_matrix(y_test, predictions)
    
    # Check per-class performance
    for class_id in [0, 1, 2]:
        class_f1 = report[str(class_id)]['f1-score']
        if class_f1 < 0.7:  # Minimum F1 score per class
            raise ValueError(f"Class {class_id} F1-score {class_f1:.4f} below threshold 0.7")
    
    print("✅ Model performance validation passed")
    print("\nClassification Report:")
    print(classification_report(y_test, predictions))
    
    return report, conf_matrix

def validate_model_api_format(model, sample_input):
    """Test model works with API input format"""
    # Test single prediction
    single_pred = model.predict([sample_input])
    assert len(single_pred) == 1, "Single prediction failed"
    
    # Test batch prediction
    batch_input = np.array([sample_input, sample_input])
    batch_pred = model.predict(batch_input)
    assert len(batch_pred) == 2, "Batch prediction failed"
    
    print("✅ Model API format validation passed")
    return True

def save_validation_results(results, output_path="/output/validation_results.json"):
    """Save validation results for downstream use"""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2, default=str)
    print(f"✅ Validation results saved to {output_path}")

def main():
    """Main validation pipeline"""
    print("🧪 Starting Model Validation Tests...")
    
    try:
        # Load model and test data
        model = load_model()
        X_test, y_test = load_test_data()
        
        # Run validation tests
        accuracy, predictions = validate_model_accuracy(model, X_test, y_test)
        validate_model_predictions(model, X_test)
        report, conf_matrix = validate_model_performance(model, X_test, y_test)
        validate_model_api_format(model, X_test[0])
        
        # Compile results
        results = {
            "validation_status": "PASSED",
            "accuracy": float(accuracy),
            "classification_report": report,
            "confusion_matrix": conf_matrix.tolist(),
            "test_count": len(X_test),
            "timestamp": str(np.datetime64('now'))
        }
        
        # Save results
        save_validation_results(results)
        
        print(f"\n🎉 All validation tests PASSED!")
        print(f"Model accuracy: {accuracy:.4f}")
        
    except Exception as e:
        print(f"\n❌ Validation FAILED: {str(e)}")
        
        # Save failure results
        failure_results = {
            "validation_status": "FAILED",
            "error": str(e),
            "timestamp": str(np.datetime64('now'))
        }
        save_validation_results(failure_results)
        
        # Exit with error code
        exit(1)

if __name__ == "__main__":
    main()