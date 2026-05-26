.PHONY: help install install-local test validate lint ci clean

help:           ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install:        ## Install safe-delete globally (~/.config/opencode/skills/)
	@echo "Installing safe-delete..."
	@bash scripts/install.sh

install-local:  ## Install safe-delete locally (.opencode/skills/)
	@echo "Installing safe-delete locally..."
	@bash scripts/install.sh --local

install-project: ## Install in current project (.opencode/)
	@echo "Installing safe-delete in project..."
	@bash scripts/install.sh --project

prereqs:        ## Check prerequisites
	@echo "Checking prerequisites..."
	@bash scripts/test-prereqs.sh

test:           ## Run all tests
	@echo "Running safe-delete tests..."
	@bash tests/test-skill-structure.sh
	@echo "---"
	@bash tests/test-risk-scoring.sh
	@echo "---"
	@echo "To run platform-specific tests:"
	@echo "  make test-windows   (PowerShell)"
	@echo "  make test-unix      (Bash)"

test-windows:   ## Run Windows/PowerShell tests
	@echo "Running Windows tests..."
	@powershell -NoProfile -ExecutionPolicy Bypass -File tests/test-risk-scoring.ps1

test-unix:      ## Run Unix/Bash tests
	@echo "Running Unix tests..."
	@bash tests/test-risk-scoring.sh

validate:       ## Validate skill structure
	@bash scripts/validate.sh

lint:           ## Check markdown formatting
	@echo "Checking markdown..."
	@command -v mdl >/dev/null 2>&1 && mdl *.md docs/*.md examples/*.md || echo "mdl not installed. Skipping markdown lint."
	@command -v markdownlint >/dev/null 2>&1 && markdownlint *.md docs/*.md examples/*.md || echo "markdownlint not installed. Skipping."

ci:             ## Run full CI pipeline
	@echo "=== Safe-Delete CI Pipeline ==="
	@make prereqs
	@make validate
	@make test
	@make lint
	@echo "=== All checks passed ==="

clean:          ## Remove temp files
	@echo "Cleaning..."
	@rm -rf tmp/
	@echo "Done."
