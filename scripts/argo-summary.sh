#!/usr/bin/env python3
import sys
import re

def filter_argo_logs():
    # Keywords to highlight important events
    important_patterns = [
        r'ERROR',
        r'WARN',
        r'Failed',
        r'Successfully',
        r'Registered model',
        r'Model registered',
        r'artifacts/model',
        r'mlflow',
        r'bucket',
        r'Training completed',
        r'Starting',
        r'Finished'
    ]
    
    # Patterns to skip (noise)
    skip_patterns = [
        r'Downloading.*\.whl',
        r'━━━━━━━━━━━━━━━━━',
        r'Collecting.*\(from',
        r'Requirement already satisfied',
        r'Installing collected packages',
        r'Obtaining file://',
        r'\s+\d+\.\d+/\d+\.\d+ MB',
        r'eta 0:00:00'
    ]
    
    # Combine important patterns
    important_regex = re.compile('|'.join(important_patterns), re.IGNORECASE)
    skip_regex = re.compile('|'.join(skip_patterns))
    
    filtered_lines = []
    current_step = None
    
    for line in sys.stdin:
        line = line.strip()
        
        # Skip empty lines and noise
        if not line or skip_regex.search(line):
            continue
            
        # Track workflow steps
        if ':' in line and any(step in line for step in ['train', 'validation', 'deploy', 'monitor']):
            parts = line.split(':', 1)
            if len(parts) > 1:
                step_name = parts[0].strip()
                if step_name != current_step:
                    current_step = step_name
                    filtered_lines.append(f"\n=== {step_name} ===")
        
        # Include important lines
        if important_regex.search(line):
            # Clean up the line
            clean_line = re.sub(r'^[^:]+:\s*', '', line)  # Remove pod prefix
            filtered_lines.append(clean_line)
        
        # Include concise training progress
        elif 'Epoch' in line and ('loss' in line or 'accuracy' in line):
            clean_line = re.sub(r'^[^:]+:\s*', '', line)
            filtered_lines.append(clean_line)
    
    # Print filtered results
    for line in filtered_lines:
        print(line)

if __name__ == "__main__":
    filter_argo_logs()
