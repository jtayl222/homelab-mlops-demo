.PHONY: demo kustomize-dev kustomize-prod validate-kustomize deploy-dev deploy-prod clean-ports

# Configuration
DEV_PORT := $(shell kubectl kustomize manifests/overlays/development 2>/dev/null | yq eval 'select(.metadata.name == "app-config") | .data.MODEL_SERVING_PORT' - 2>/dev/null || echo "9001")
PROD_PORT := $(shell kubectl kustomize manifests/overlays/production 2>/dev/null | yq eval 'select(.metadata.name == "app-config") | .data.MODEL_SERVING_PORT' - 2>/dev/null || echo "9000")

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
	./scripts/restart-demo.sh argowf-dev development

demo-prod:
	./scripts/restart-demo.sh argowf production

# Port management
show-config:
	@echo "Development port: $(DEV_PORT)"
	@echo "Production port: $(PROD_PORT)"

port-forward-dev:
	kubectl port-forward -n argowf-dev svc/dev-iris-0-2-0-default-classifier $(DEV_PORT):$(DEV_PORT)

port-forward-prod:
	kubectl port-forward -n argowf svc/iris-0-2-0-default-classifier $(PROD_PORT):$(PROD_PORT)

# Testing
smoke-test-dev:
	./scripts/smoke-test.sh argowf-dev development

smoke-test-prod:
	./scripts/smoke-test.sh argowf production

# Cleanup
clean-ports:
	@echo "Cleaning up hardcoded port references..."
	@echo "Current hardcoded 9000 references:"
	@grep -r "9000" --exclude-dir=.git --exclude="*.yaml" . | grep -v "app-config" || true

cleanup:
	@echo "Cleaning up workflows..."
	@argo delete --all -n argowf 2>/dev/null || true
	@argo delete --all -n argowf-dev 2>/dev/null || true

help:
	@echo "Available targets:"
	@echo "  demo          - Submit workflow to production"
	@echo "  demo-dev      - Deploy dev environment and submit workflow"
	@echo "  demo-prod     - Deploy prod environment and submit workflow"
	@echo "  deploy-dev    - Deploy to development environment"
	@echo "  deploy-prod   - Deploy to production environment"
	@echo "  show-config   - Show current port configuration"
	@echo "  port-forward-dev - Port forward development service"
	@echo "  port-forward-prod - Port forward production service"
	@echo "  smoke-test-dev - Run smoke test against development"
	@echo "  smoke-test-prod - Run smoke test against production"
	@echo "  clean-ports   - Show remaining hardcoded port references"
	@echo "  cleanup       - Delete all workflows"
	@echo "  validate-kustomize - Validate all kustomizations"
