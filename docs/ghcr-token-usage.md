# GitHub Container Registry (GHCR) Authentication Guide

This document provides step-by-step instructions for creating and using GitHub Personal Access Tokens (PAT) with GitHub Container Registry (GHCR) for Kubernetes deployments.

## Why GHCR Authentication is Needed

GitHub Container Registry requires authentication even for public repositories in many cases. When Kubernetes tries to pull images from `ghcr.io`, it needs proper credentials to avoid the common error:

```
failed to authorize: failed to fetch anonymous token: unexpected status from GET request to https://ghcr.io/token: 403 Forbidden
```

## Step-by-Step Token Creation

### 1. Navigate to GitHub Token Settings

1. Go to [GitHub Settings → Personal Access Tokens](https://github.com/settings/tokens)
2. Click "Generate new token" → "Generate new token (classic)"
3. Give your token a descriptive name: `homelab-mlops-ghcr-access`

### 2. Set Token Expiration

- **Recommended**: 90 days for demo/development purposes
- **Production**: 30 days with automated rotation
- **Testing**: No expiration (less secure, but convenient for demos)

### 3. Required Scopes/Permissions

Select these specific scopes:

#### Essential Scopes:
- ✅ **`read:packages`** - Download packages from GitHub Package Registry
- ✅ **`write:packages`** - Upload packages to GitHub Package Registry
- ✅ **`delete:packages`** - Delete packages from GitHub Package Registry (optional)

#### Repository Access (if your container images are in a private repo):
- ✅ **`repo`** - Full control of private repositories
  - This includes `repo:status`, `repo_deployment`, `public_repo`, `repo:invite`, `security_events`

#### For Public Repositories Only:
- ✅ **`public_repo`** - Access public repositories (if you don't need full `repo` access)

#### Additional Helpful Scopes:
- ✅ **`workflow`** - Update GitHub Action workflows (if you plan to automate with GitHub Actions)
- ✅ **`user:email`** - Access user email addresses (sometimes needed for container metadata)

### 4. Generate and Copy Token

1. Click "Generate token"
2. **IMMEDIATELY COPY THE TOKEN** - it won't be shown again
3. Store it securely (password manager, environment variable, etc.)

The token will look like: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

## Kubernetes Secret Creation

### Method 1: Direct Command (Recommended for Testing)

```bash
# Replace with your actual values
export GITHUB_USERNAME="your-github-username"
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export GITHUB_EMAIL="your-email@example.com"

# Create the secret
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username="$GITHUB_USERNAME" \
  --docker-password="$GITHUB_TOKEN" \
  --docker-email="$GITHUB_EMAIL" \
  -n argowf
```

### Method 2: Environment Variables with Script

Create a script `create-ghcr-credentials.sh`:

```bash
#!/bin/bash
# create-ghcr-credentials.sh

# Check if environment variables are set
if [[ -z "$GITHUB_USERNAME" || -z "$GITHUB_TOKEN" || -z "$GITHUB_EMAIL" ]]; then
    echo "Error: Please set the following environment variables:"
    echo "  export GITHUB_USERNAME='your-username'"
    echo "  export GITHUB_TOKEN='ghp_your_token_here'"
    echo "  export GITHUB_EMAIL='your-email@example.com'"
    exit 1
fi

# Delete existing secret if it exists
kubectl delete secret ghcr-credentials -n argowf 2>/dev/null || echo "No existing secret found"

# Create new secret
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username="$GITHUB_USERNAME" \
  --docker-password="$GITHUB_TOKEN" \
  --docker-email="$GITHUB_EMAIL" \
  -n argowf

# Verify secret creation
if kubectl get secret ghcr-credentials -n argowf >/dev/null 2>&1; then
    echo "✅ Secret 'ghcr-credentials' created successfully in namespace 'argowf'"
else
    echo "❌ Failed to create secret"
    exit 1
fi
```

Make it executable and run:
```bash
chmod +x create-ghcr-credentials.sh

# Set environment variables
export GITHUB_USERNAME="jtayl222"
export GITHUB_TOKEN="ghp_your_actual_token_here"
export GITHUB_EMAIL="your-email@example.com"

# Run the script
./create-ghcr-credentials.sh
```

### Method 3: YAML Manifest (Not Recommended - Security Risk)

**⚠️ WARNING: This method stores credentials in plain text. Only use for testing.**

```yaml
# ghcr-credentials.yaml (DO NOT COMMIT TO GIT)
apiVersion: v1
kind: Secret
metadata:
  name: ghcr-credentials
  namespace: argowf
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: |
    # This needs to be base64 encoded JSON - use Method 1 instead
```

## Verifying Token Permissions

### Test 1: Docker Login (Local Test)

```bash
# Test the token locally with Docker
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin

# Try to pull an image (if one exists)
docker pull ghcr.io/jtayl222/iris:latest

# Logout
docker logout ghcr.io
```

### Test 2: Kubernetes Secret Verification

```bash
# Check if secret exists
kubectl get secret ghcr-credentials -n argowf

# Decode and inspect the secret (for debugging)
kubectl get secret ghcr-credentials -n argowf -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq .

# Expected output should show:
# {
#   "auths": {
#     "ghcr.io": {
#       "username": "your-username",
#       "password": "ghp_...",
#       "email": "your-email@example.com",
#       "auth": "base64-encoded-username:password"
#     }
#   }
# }
```

### Test 3: Pod Image Pull Test

Create a test pod to verify image pulling:

```bash
# Create test pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ghcr-test
  namespace: argowf
spec:
  imagePullSecrets:
  - name: ghcr-credentials
  containers:
  - name: test
    image: ghcr.io/jtayl222/iris:latest
    command: ["sleep", "3600"]
  restartPolicy: Never
EOF

# Check if pod starts successfully
kubectl get pod ghcr-test -n argowf
kubectl describe pod ghcr-test -n argowf

# Clean up test pod
kubectl delete pod ghcr-test -n argowf
```

## Common Issues and Solutions

### Issue 1: "403 Forbidden" Error

**Problem**: 
```
failed to authorize: failed to fetch anonymous token: 403 Forbidden
```

**Solutions**:
1. **Check token permissions**: Ensure `read:packages` and `write:packages` are selected
2. **Verify token is not expired**: Check token expiration date
3. **Check repository visibility**: Private repos need `repo` scope
4. **Verify username**: Must match exactly (case-sensitive)

### Issue 2: "Invalid Username or Password"

**Problem**:
```
Error response from daemon: invalid username/password
```

**Solutions**:
1. **Check token format**: Should start with `ghp_`
2. **Verify username**: Use GitHub username, not email
3. **Check for special characters**: Username should not contain special characters
4. **Regenerate token**: Old token might be corrupted

### Issue 3: "Package Does Not Exist"

**Problem**:
```
failed to resolve reference "ghcr.io/username/package:tag": not found
```

**Solutions**:
1. **Check package name**: Verify exact package name in GitHub Packages
2. **Check tag**: Ensure the tag (e.g., `latest`) exists
3. **Repository linking**: Ensure package is linked to the correct repository
4. **Push an image first**: The package must exist before pulling

### Issue 4: Kubernetes Secret Not Working

**Problem**: Secret exists but pods still can't pull images

**Solutions**:
1. **Check secret format**:
   ```bash
   kubectl get secret ghcr-credentials -n argowf -o yaml
   ```

2. **Verify imagePullSecrets in deployment**:
   ```yaml
   spec:
     imagePullSecrets:
     - name: ghcr-credentials  # Must match secret name exactly
   ```

3. **Check namespace**: Secret and pod must be in same namespace

4. **Recreate secret with correct format**:
   ```bash
   kubectl delete secret ghcr-credentials -n argowf
   # Use Method 1 above to recreate
   ```

## GitHub Package Repository Setup

### Making Your Package Public

1. Go to your GitHub repository
2. Navigate to "Packages" (right sidebar)
3. Click on your package (e.g., `iris`)
4. Go to "Package settings"
5. Under "Danger Zone" → "Change package visibility"
6. Select "Public" and confirm

### Linking Package to Repository

1. In package settings
2. Under "Manage Actions access"
3. Ensure your repository has read/write access
4. Link the package to your repository if not automatically linked

### Package Permissions

For private packages, ensure your token has access:
1. Repository must be accessible with your token's `repo` scope
2. Package permissions should allow your user/token access
3. Organization packages may need additional permissions

## Automation and Best Practices

### Environment Variables for CI/CD

```bash
# For GitHub Actions
GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}  # Built-in token
# OR
GHCR_TOKEN: ${{ secrets.GHCR_TOKEN }}      # Custom token with package permissions

# For local development
export GITHUB_USERNAME="your-username"
export GITHUB_TOKEN="$(cat ~/.github-token)"  # Store token in file
export GITHUB_EMAIL="your-email@example.com"
```

### Token Rotation Strategy

1. **Set expiration**: Use 30-90 day expiration
2. **Document expiration**: Add calendar reminder
3. **Automate creation**: Use GitHub API to create tokens programmatically
4. **Monitor usage**: Check token usage in GitHub settings

### Security Best Practices

1. **Minimal permissions**: Only grant necessary scopes
2. **Environment-specific tokens**: Different tokens for dev/staging/prod
3. **Regular rotation**: Rotate tokens every 30-90 days
4. **Secure storage**: Use secret management systems (Vault, AWS Secrets Manager)
5. **Audit access**: Regularly review token usage and permissions

## Integration with MLOps Pipeline

### Update Seldon Deployment

Ensure your Seldon deployment uses the registry secret:

```yaml
# In your workflow.yaml deploy step
apiVersion: machinelearning.seldon.io/v1
kind: SeldonDeployment
metadata:
  name: iris
  namespace: argowf
spec:
  predictors:
  - name: default
    componentSpecs:
    - spec:
        imagePullSecrets:
        - name: ghcr-credentials  # Add this line
        containers:
        - name: classifier
          image: ghcr.io/jtayl222/iris:latest
```

### Restart Script Integration

Update your `restart-demo.sh` to handle token setup:

```bash
# In restart-demo.sh, add token validation
echo "Validating GitHub token..."
if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "❌ GITHUB_TOKEN not set. Please run:"
    echo "export GITHUB_TOKEN='ghp_your_token_here'"
    exit 1
fi

# Test token validity
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo "✅ GitHub token is valid"
    docker logout ghcr.io >/dev/null 2>&1
else
    echo "❌ GitHub token is invalid or expired"
    exit 1
fi
```

Remember: Your GitHub token is like a password. Keep it secure and rotate it regularly!