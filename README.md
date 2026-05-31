# Mac dotfiles

Personal macOS dotfiles, app settings, Homebrew package list, and setup helpers.

## Fresh Mac Setup

Run these commands from Terminal on a fresh Mac.

1. Install Homebrew using the official installer from [brew.sh](https://brew.sh/):

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

2. Follow any shell setup instructions the Homebrew installer prints so `brew` is on your `PATH`.

3. Clone this repo and bootstrap from `~/dotfiles`:

```sh
git clone git@github.com:dgitman/dotfiles.git ~/dotfiles
cd ~/dotfiles
make bootstrap
```

4. Optional: restore private credential-bearing files from 1Password:

```sh
make restore
```

5. Restart your terminal.

## What Bootstrap Does

`make bootstrap` links dotfiles into the right places and installs the apps/tools listed in `brew/Brewfile`.

## Common Commands

Run these from `~/dotfiles`.

```sh
make bootstrap         # Link dotfiles and install Homebrew packages
make install           # Link dotfiles only
make check             # Verify links/templates without changing anything
make brew-update       # Manually regenerate brew/Brewfile
make restore           # Restore private files from 1Password references
make store             # Store supported private files in 1Password
make op-shell          # Open a shell with 1Password env secrets loaded
make op-run CMD='...'  # Run one command with 1Password env secrets loaded
make secrets           # Scan current files for leaked secrets
make secrets-history   # Scan Git history for leaked secrets
make hooks             # Install local Git hooks
make launchd           # Install scheduled dotfiles jobs
```

In zsh, `brew install`, `brew uninstall`, `brew remove`, `brew rm`, `brew reinstall`, `brew tap`, and `brew untap` automatically run `make brew-update` after they succeed. The hourly auto-sync job commits and pushes the updated `brew/Brewfile`.

## What's included

- Zsh shell setup
- Git defaults and signing setup
- 1Password SSH agent config
- Homebrew bundle for command-line tools, apps, Mac App Store apps, and VS Code extensions
- VS Code, Cursor, Claude, and Warp settings
- Codex and rbenv settings
- Optional 1Password-backed restore helper for credential-bearing local config files
- A small install script that backs up existing files before linking these dotfiles

## Credentials And Secrets

Private credentials should live in 1Password, not in this repo.

- Store `op://...` references, examples, and templates in Git.
- Do not store raw tokens, OAuth JSON, private keys, database credentials, or shell history.
- Use `make restore` to rebuild supported private local files from 1Password.
- Use `make store` to update supported 1Password-backed files.

Secret scanning uses `gitleaks`. The Git hooks and the hourly auto-sync job run it before committing or pushing. This repo's `.gitleaks.toml` also blocks credential-bearing dotfile paths such as local GitHub, Google Cloud, and 1Password env files.

## Automatic Sync

`make launchd` installs scheduled macOS jobs:

- hourly auto-sync for this repo
- daily dotfiles check

The auto-sync job commits changes with `Update dotfiles`, pulls with rebase, and pushes `main` to `origin`. Logs are written under `logs/`, which is intentionally ignored.

## Layout

```text
dotfiles/   Home-directory shell dotfiles
git/        Git dotfiles
ssh/        SSH client configuration
brew/       Homebrew bundle
bin/        Commands exposed through ~/.local/bin
config/     Safe app configuration, editor settings, runtime settings, and 1Password reference templates
docs/       Notes for credential restoration and secret handling
launchd/    macOS scheduled job
hooks/      Local Git hooks
scripts/    Setup helpers
```

## Notes

The install script creates timestamped backups for files it replaces. It also keeps `~/.local/bin` first on `PATH` and points it at `~/dotfiles/bin`.

Secrets, private keys, shell histories, and local machine state are intentionally ignored.
