.PHONY: install check secrets secrets-history brew-update brew-cleanup restore store hooks launchd

install:        ## Symlink all dotfiles into place (backs up existing files)
	./scripts/install.sh

check:          ## Validate all declared symlinks/templates without making changes
	./scripts/install.sh --check

secrets:        ## Scan working tree for accidentally committed secrets
	./scripts/scan-secrets.sh

secrets-history: ## Scan full git history for secrets
	./scripts/scan-secrets.sh --history

brew-update:    ## Regenerate Brewfile from current machine and push
	python3 brew/update.py

brew-cleanup:   ## Preview packages installed locally but absent from Brewfile
	python3 brew/cleanup_preview.py

restore:        ## Restore 1Password-backed credential files to their live paths
	./scripts/restore-op-files.sh

store:          ## Store supported local credential files in 1Password
	./scripts/store-op-files.sh

hooks:          ## Install pre-commit and pre-push Git hooks
	./scripts/install-git-hooks.sh

launchd:        ## Install the hourly auto-sync launchd job
	./scripts/install-launchagent.sh

help:           ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*##"}; {printf "  %-18s %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
