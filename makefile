.PHONY: demo kustomize-dev kustomize-prod validate-kustomize deploy-dev deploy-prod clean-ports

# Dynamic configuration
DEV_PORT := $(shell ./scripts/get-config.sh development 2>/dev/null || echo "9001")
PROD_PORT := $(shell ./scripts/get-config.sh production 2>/dev/null || echo "9000")

demo:
	argo submit manifests/base/workflows/iris-workflow.yaml -n argowf --watch

kustomize-dev:
	kubectl kustomize manifests/overlays/development

kustomize-prod:
	kubectl kustomize manifests/overlays/production

validate-kustomize:
	./scripts/validate-kustomize.sh

deploy-dev: validate-kustomize
	kubectl apply -k manifests/overlays/development

deploy-prod: validate-kustomize
	kubectl apply -k manifests/overlays/production

# Workflow management
demo-dev:
	./scripts/restart-demo.sh argowf-dev deploy

demo-prod:
	./scripts/restart-demo.sh argowf deploy

# Port management
show-config:
	@echo "Current configuration:"
	@echo "  Development port: $(DEV_PORT)"
	@echo "  Production port:  $(PROD_PORT)"
	@echo ""
	@echo "Development ConfigMap name:"
	@kubectl kustomize manifests/overlays/development 2>/dev/null | yq eval 'select(.kind == "ConfigMap" and (.metadata.name | test(".*app-config"))) | .metadata.name' - 2>/dev/null || echo "N/A"
	@echo "Production ConfigMap name:"
	@kubectl kustomize manifests/overlays/production 2>/dev/null | yq eval 'select(.kind == "ConfigMap" and (.metadata.name | test(".*app-config"))) | .metadata.name' - 2>/dev/null || echo "N/A"

port-forward-dev:
	@echo "Port forwarding development service on port $(DEV_PORT)..."
	kubectl port-forward -n argowf-dev svc/dev-iris-0-2-0-default-classifier $(DEV_PORT):$(DEV_PORT)

port-forward-prod:
	@echo "Port forwarding production service on port $(PROD_PORT)..."
	kubectl port-forward -n argowf svc/iris-0-2-0-default-classifier $(PROD_PORT):$(PROD_PORT)

# Configuration management
preview-dev:
	kubectl kustomize manifests/overlays/development | less

preview-prod:
	kubectl kustomize manifests/overlays/production | less

check-ports:
	@echo "Checking port configurations..."
	@echo "Development port: $(DEV_PORT)"
	@echo "Production port: $(PROD_PORT)"
	@kubectl kustomize manifests/overlays/development 2>/dev/null | grep -E "$(DEV_PORT)" || true
	@kubectl kustomize manifests/overlays/production 2>/dev/null | grep -E "$(PROD_PORT)" || true

# Testing
smoke-test-dev:
	./scripts/smoke-test.sh argowf-dev development

smoke-test-prod:
	./scripts/smoke-test.sh argowf production

# Workflow status
workflow-status:
	@echo "Current workflows:"
	@argo list -n argowf 2>/dev/null || echo "No workflows in argowf namespace"
	@argo list -n argowf-dev 2>/dev/null || echo "No workflows in argowf-dev namespace"

# Clean up workflows
cleanup:
	@echo "Cleaning up workflows..."
	@argo delete --all -n argowf 2>/dev/null || true
	@argo delete --all -n argowf-dev 2>/dev/null || true

# Show remaining hardcoded references
clean-ports:
	@echo "Remaining hardcoded port references:"
	@grep -r "9000\|9001" --exclude-dir=.git --exclude="*.yaml" . | grep -v "app-config" | grep -v "get-config" || echo "No hardcoded ports found!"

# Complete environment setup
setup-dev:
	kubectl create namespace argowf-dev --dry-run=client -o yaml | kubectl apply -f -
	make deploy-dev
	make demo-dev

setup-prod:
	kubectl create namespace argowf --dry-run=client -o yaml | kubectl apply -f -
	make deploy-prod
	make demo-prod

# Full restart (cleanup + deploy + demo)
restart-dev:
	./scripts/restart-demo.sh argowf-dev restart

restart-prod:
	./scripts/restart-demo.sh argowf restart

# Clean only
clean-dev:
	./scripts/restart-demo.sh argowf-dev clean

clean-prod:
	./scripts/restart-demo.sh argowf clean

help:
	@echo "Available targets:"
	@echo ""
	@echo "Quick Start:"
	@echo "  setup-dev         - Create dev namespace, deploy, and run demo"
	@echo "  setup-prod        - Create prod namespace, deploy, and run demo"
	@echo ""
	@echo "Environment Management:"
	@echo "  deploy-dev        - Deploy to development environment"
	@echo "  deploy-prod       - Deploy to production environment"
	@echo "  demo-dev          - Deploy dev environment and submit workflow"
	@echo "  demo-prod         - Deploy prod environment and submit workflow"
	@echo "  restart-dev       - Full restart of development environment"
	@echo "  restart-prod      - Full restart of production environment"
	@echo ""
	@echo "Configuration:"
	@echo "  show-config       - Show current port configuration"
	@echo "  preview-dev       - Preview development manifests"
	@echo "  preview-prod      - Preview production manifests"
	@echo "  check-ports       - Verify port configurations"
	@echo "  validate-kustomize - Validate all kustomizations"
	@echo ""
	@echo "Testing:"
	@echo "  smoke-test-dev    - Run smoke test against development"
	@echo "  smoke-test-prod   - Run smoke test against production"
	@echo "  port-forward-dev  - Port forward development service"
	@echo "  port-forward-prod - Port forward production service"
	@echo ""
	@echo "Monitoring:"
	@echo "  workflow-status   - Check workflow status"
	@echo ""
	@echo "Cleanup:"
	@echo "  clean-dev         - Clean development environment only"
	@echo "  clean-prod        - Clean production environment only"
	@echo "  cleanup           - Delete all workflows"
	@echo "  clean-ports       - Show remaining hardcoded port references"
	@echo ""
	@echo "Development:"
	@echo "  kustomize-dev     - Show development kustomization"
	@echo "  kustomize-prod    - Show production kustomization"
	@echo "  demo              - Submit workflow to production (simple)"
