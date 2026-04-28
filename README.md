# Mac dotfiles

Personal macOS dotfiles and bootstrap helpers.

## What's included

- Zsh shell setup
- Git defaults and signing setup
- 1Password SSH agent config
- Homebrew bundle for command-line tools, apps, Mac App Store apps, and VS Code extensions
- VS Code, Cursor, Claude, and Warp settings
- Codex and rbenv settings
- Optional 1Password-backed restore helper for credential-bearing local config files
- A small install script that backs up existing files before linking these dotfiles

## Install

```sh
./scripts/install.sh
```

To install packages from the Brewfile:

```sh
brew bundle --file brew/Brewfile
```

To restore local credential-bearing files from 1Password references:

```sh
./scripts/restore-op-files.sh
```

To store supported local credential files in 1Password and update the local references:

```sh
./scripts/store-op-files.sh
```

## Secret checks

Run a local secret scan before making the repository public or pushing changes:

```sh
./scripts/scan-secrets.sh
./scripts/scan-secrets.sh --history
```

Install Git hooks that run the scanner before commits and pushes:

```sh
./scripts/install-git-hooks.sh
```

The hourly auto-sync job also runs this scan before it commits or pushes. The scanner blocks common private keys, GitHub tokens, OpenAI keys, AWS keys, Google API keys, Slack tokens, and simple `password`, `token`, `secret`, or `api_key` assignments.

## Automatic sync

Install the hourly auto-sync job:

```sh
./scripts/install-launchagent.sh
```

The job commits changes in this repository with `Update dotfiles`, pulls with rebase, and pushes `main` to `origin`. Logs are written under `logs/`, which is intentionally ignored.

## Layout

```text
dotfiles/   Home-directory shell dotfiles
git/        Git dotfiles
ssh/        SSH client configuration
brew/       Homebrew bundle
config/     Safe app configuration, editor settings, runtime settings, and 1Password reference templates
docs/       Notes for credential restoration and secret handling
launchd/    macOS scheduled job
hooks/      Local Git hooks
scripts/    Setup helpers
```

## Notes

The install script creates timestamped backups for files it replaces. Secrets, private keys, shell histories, and local machine state are intentionally ignored.
