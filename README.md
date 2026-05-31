# Mac dotfiles

Personal macOS dotfiles and bootstrap helpers.

## Fresh Mac

Install Homebrew first. Then clone this repo and run `make bootstrap` from the `~/dotfiles` directory:

```sh
git clone git@github.com:dgitman/dotfiles.git ~/dotfiles
cd ~/dotfiles
make bootstrap
```

`make bootstrap` links the dotfiles into place and installs all packages from `brew/Brewfile`.

If you also want to restore private credential-bearing files from 1Password, stay in `~/dotfiles` and run:

```sh
make restore
```

Restart your terminal after bootstrap finishes.

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
make bootstrap
```

This links the dotfiles into place and installs all packages from `brew/Brewfile`.

To link dotfiles without installing Homebrew packages:

```sh
make install
```

The installer also ensures `~/.local/bin` is first on `PATH` and points `~/.local/bin` at `~/dotfiles/bin`.

To update the Brewfile from the current machine and push it:

```sh
brewfile-update
```

After running `./scripts/install.sh` (and restarting your terminal), `brewfile-update` is also available as a shortcut for updating and pushing the Brewfile.

To restore local credential-bearing files from 1Password references:

```sh
make restore
```

To store supported local credential files in 1Password and update the local references:

```sh
make store
```

## Secret checks

Run a local secret scan before making the repository public or pushing changes:

```sh
make secrets
make secrets-history
```

Install Git hooks that run the scanner before commits and pushes:

```sh
./scripts/install-git-hooks.sh
```

The hourly auto-sync job also runs this scan before it commits or pushes. Gitleaks blocks common private keys, service tokens, cloud credentials, and other high-risk secrets. This repo's `.gitleaks.toml` also blocks credential-bearing dotfile paths such as local GitHub, Google Cloud, and 1Password env files.

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
bin/        Personal scripts (see `bin/README.md`)
config/     Safe app configuration, editor settings, runtime settings, and 1Password reference templates
docs/       Notes for credential restoration and secret handling
launchd/    macOS scheduled job
hooks/      Local Git hooks
scripts/    Setup helpers
```

## Notes

The install script creates timestamped backups for files it replaces. Secrets, private keys, shell histories, and local machine state are intentionally ignored.
