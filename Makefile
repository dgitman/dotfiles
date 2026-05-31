.PHONY: bootstrap install check secrets secrets-history brew-update restore store op-shell op-run hooks launchd

OP_ENV_FILE ?= $(HOME)/.config/op/dotfiles.env

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

brew-update:    ## Regenerate Brewfile from current machine
	brew bundle dump --force --describe --file brew/Brewfile

restore:        ## Restore 1Password-backed credential files to their live paths
	./scripts/restore-op-files.sh

store:          ## Store supported local credential files in 1Password
	./scripts/store-op-files.sh

op-shell:       ## Open a shell with 1Password env secrets loaded
	op run --env-file "$(OP_ENV_FILE)" -- "$$SHELL"

op-run:         ## Run CMD='...' with 1Password env secrets loaded
	@test -n "$(CMD)" || (printf 'Usage: make op-run CMD="some-command"\n' >&2; exit 1)
	op run --env-file "$(OP_ENV_FILE)" -- $(CMD)

hooks:          ## Install pre-commit and pre-push Git hooks
	mkdir -p .git/hooks
	ln -sf "$(PWD)/hooks/pre-commit" .git/hooks/pre-commit
	ln -sf "$(PWD)/hooks/pre-push" .git/hooks/pre-push
	@printf 'installed dotfiles Git hooks\n'

launchd:        ## Install all launchd agents (daily auto-sync + daily check)
	mkdir -p "$(HOME)/Library/LaunchAgents" logs
	@for plist in launchd/*.plist; do \
		plist_name="$$(basename "$$plist")"; \
		target="$(HOME)/Library/LaunchAgents/$$plist_name"; \
		cp "$$plist" "$$target"; \
		launchctl unload "$$target" 2>/dev/null || true; \
		launchctl load -w "$$target"; \
		printf 'installed %s\n' "$$target"; \
	done

help:           ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*##"}; {printf "  %-18s %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
