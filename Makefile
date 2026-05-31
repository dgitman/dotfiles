.PHONY: bootstrap install check secrets secrets-history brew-update restore store hooks launchd

bootstrap:      ## Install dotfiles and Homebrew packages from the Brewfile
	./scripts/install.sh
	brew bundle install --file brew/Brewfile

install:        ## Symlink all dotfiles into place (backs up existing files)
	./scripts/install.sh

check:          ## Validate all declared symlinks/templates without making changes
	./scripts/install.sh --check

secrets:        ## Scan working tree for accidentally committed secrets
	gitleaks dir . --redact --no-banner

secrets-history: ## Scan full git history for secrets
	gitleaks git . --redact --no-banner

brew-update:    ## Regenerate Brewfile from current machine and push
	./bin/brewfile-update

restore:        ## Restore 1Password-backed credential files to their live paths
	./scripts/restore-op-files.sh

store:          ## Store supported local credential files in 1Password
	./scripts/store-op-files.sh

hooks:          ## Install pre-commit and pre-push Git hooks
	./scripts/install-git-hooks.sh

launchd:        ## Install all launchd agents (hourly auto-sync + daily check)
	./scripts/install-launchagent.sh

help:           ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*##"}; {printf "  %-18s %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
