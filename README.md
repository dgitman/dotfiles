# Mac dotfiles

Personal macOS dotfiles and bootstrap helpers.

## What's included

- Zsh shell setup
- Git defaults and signing setup
- 1Password SSH agent config
- Homebrew bundle for command-line tools, apps, Mac App Store apps, and VS Code extensions
- A small install script that backs up existing files before linking these dotfiles

## Install

```sh
./scripts/install.sh
```

To install packages from the Brewfile:

```sh
brew bundle --file brew/Brewfile
```

## Automatic sync

Install the hourly auto-sync job:

```sh
./scripts/install-launchagent.sh
```

The job commits changes in this repository with `Update dotfiles`, pulls with rebase, and pushes `main` to `origin`. Logs are written under `logs/`, which is intentionally ignored.

## Layout

```text
dotfiles/   Home-directory dotfiles
git/        Git-related files
ssh/        SSH client configuration
brew/       Homebrew bundle
launchd/    macOS scheduled job
scripts/    Setup helpers
```

## Notes

The install script creates timestamped backups for files it replaces. Secrets, private keys, shell histories, and local machine state are intentionally ignored.
