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

## Layout

```text
dotfiles/   Home-directory dotfiles
git/        Git-related files
ssh/        SSH client configuration
brew/       Homebrew bundle
scripts/    Setup helpers
```

## Notes

The install script creates timestamped backups for files it replaces. Secrets, private keys, shell histories, and local machine state are intentionally ignored.
