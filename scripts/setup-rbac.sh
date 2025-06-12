#!/bin/bash
set -e

SOURCE_NAMESPACE=${1:-argowf}
TARGET_NAMESPACE=${2:-argowf-dev}

echo "🔐 Setting up RBAC for namespace: $TARGET_NAMESPACE"
echo "   Source: $SOURCE_NAMESPACE"

# Validate source namespace exists
if ! kubectl get namespace "$SOURCE_NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Source namespace '$SOURCE_NAMESPACE' does not exist"
    exit 1
fi

# Validate target namespace exists
if ! kubectl get namespace "$TARGET_NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Target namespace '$TARGET_NAMESPACE' does not exist"
    exit 1
fi

echo ""
echo "👤 Creating service account..."
kubectl create serviceaccount argo-workflow -n "$TARGET_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "📋 Copying Roles from $SOURCE_NAMESPACE to $TARGET_NAMESPACE..."

# Function to copy role with conflict resolution
copy_role_with_conflict_resolution() {
    local role_name=$1
    local source_ns=$2
    local target_ns=$3
    
    echo "Copying role: $role_name"
    
    # Check if role exists in source
    if ! kubectl get role "$role_name" -n "$source_ns" >/dev/null 2>&1; then
        echo "⚠️  Role '$role_name' not found in source namespace '$source_ns', skipping"
        return 0
    fi
    
    # Delete existing role in target namespace to avoid conflicts
    kubectl delete role "$role_name" -n "$target_ns" --ignore-not-found
    
    # Copy role with cleaned metadata
    kubectl get role "$role_name" -n "$source_ns" -o yaml | \
        sed "s/namespace: $source_ns/namespace: $target_ns/" | \
        sed '/resourceVersion:/d; /uid:/d; /creationTimestamp:/d; /generation:/d' | \
        kubectl apply -f -
    
    echo "✅ Role '$role_name' copied successfully"
}

# Copy each role individually with conflict resolution
ROLES_TO_COPY=(
    "argo-workflows-workflow"
    "seldon-deployment-manager" 
    "workflow-role"
    "seldon-manager-role"  # Add this line
)

for role in "${ROLES_TO_COPY[@]}"; do
    copy_role_with_conflict_resolution "$role" "$SOURCE_NAMESPACE" "$TARGET_NAMESPACE"
done

echo ""
echo "🔗 Creating RoleBindings..."

# Function to copy rolebinding with conflict resolution
copy_rolebinding_with_conflict_resolution() {
    local rb_name=$1
    local source_ns=$2
    local target_ns=$3
    
    echo "Copying rolebinding: $rb_name"
    
    # Check if rolebinding exists in source
    if ! kubectl get rolebinding "$rb_name" -n "$source_ns" >/dev/null 2>&1; then
        echo "⚠️  RoleBinding '$rb_name' not found in source namespace '$source_ns', skipping"
        return 0
    fi
    
    # Delete existing rolebinding in target namespace to avoid conflicts
    kubectl delete rolebinding "$rb_name" -n "$target_ns" --ignore-not-found
    
    # Copy rolebinding with cleaned metadata and updated namespace references
    kubectl get rolebinding "$rb_name" -n "$source_ns" -o yaml | \
        sed "s/namespace: $source_ns/namespace: $target_ns/g" | \
        sed "s/name: $source_ns/name: $target_ns/g" | \
        sed '/resourceVersion:/d; /uid:/d; /creationTimestamp:/d; /generation:/d' | \
        kubectl apply -f -
    
    echo "✅ RoleBinding '$rb_name' copied successfully"
}

# Copy rolebindings
ROLEBINDINGS_TO_COPY=(
    "argo-workflows-workflow-binding"
    "seldon-deployment-manager-binding"
    "workflow-binding"
    "seldon-manager-binding"  # Add this line
)

for rb in "${ROLEBINDINGS_TO_COPY[@]}"; do
    copy_rolebinding_with_conflict_resolution "$rb" "$SOURCE_NAMESPACE" "$TARGET_NAMESPACE"
done

echo ""
echo "🔍 Verifying RBAC setup..."
echo "Service Accounts:"
kubectl get serviceaccounts -n "$TARGET_NAMESPACE" | grep argo-workflow || echo "❌ ServiceAccount not found"

echo ""
echo "Roles:"
for role in "${ROLES_TO_COPY[@]}"; do
    if kubectl get role "$role" -n "$TARGET_NAMESPACE" >/dev/null 2>&1; then
        echo "✅ $role"
    else
        echo "❌ $role"
    fi
done

echo ""
echo "RoleBindings:"
for rb in "${ROLEBINDINGS_TO_COPY[@]}"; do
    if kubectl get rolebinding "$rb" -n "$TARGET_NAMESPACE" >/dev/null 2>&1; then
        echo "✅ $rb"
    else
        echo "❌ $rb"
    fi
done

echo ""
echo "🔧 Creating essential RoleBindings if missing..."

# Ensure critical Seldon deployment binding exists
if ! kubectl get rolebinding argo-workflow-can-manage-seldon-deployments -n "$TARGET_NAMESPACE" >/dev/null 2>&1; then
    echo "Creating missing Seldon deployment RoleBinding..."
    kubectl create rolebinding argo-workflow-can-manage-seldon-deployments \
      --role=seldon-deployment-manager \
      --serviceaccount="$TARGET_NAMESPACE:argo-workflow" \
      -n "$TARGET_NAMESPACE"
    echo "✅ Seldon deployment RoleBinding created"
fi

# Ensure argo-workflows binding exists
if ! kubectl get rolebinding argo-workflows-workflow -n "$TARGET_NAMESPACE" >/dev/null 2>&1; then
    echo "Creating missing Argo Workflows RoleBinding..."
    kubectl create rolebinding argo-workflows-workflow \
      --role=argo-workflows-workflow \
      --serviceaccount="$TARGET_NAMESPACE:argo-workflow" \
      -n "$TARGET_NAMESPACE"
    echo "✅ Argo Workflows RoleBinding created"
fi

echo ""
echo "✅ RBAC setup completed for $TARGET_NAMESPACE"