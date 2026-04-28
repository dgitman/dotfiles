#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

link_file() {
  local source="$1"
  local target="$2"

  mkdir -p "$(dirname "$target")"

  if [ -e "$target" ] || [ -L "$target" ]; then
    mkdir -p "$BACKUP_DIR$(dirname "$target")"
    mv "$target" "$BACKUP_DIR$target"
  fi

  ln -s "$source" "$target"
  printf 'linked %s -> %s\n' "$target" "$source"
}

link_file "$ROOT/dotfiles/.zshrc" "$HOME/.zshrc"
link_file "$ROOT/dotfiles/.zprofile" "$HOME/.zprofile"
link_file "$ROOT/git/.gitconfig" "$HOME/.gitconfig"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
link_file "$ROOT/ssh/config" "$HOME/.ssh/config"
chmod 600 "$ROOT/ssh/config"

link_file "$ROOT/config/gh/config.yml" "$HOME/.config/gh/config.yml"
link_file "$ROOT/config/gcloud/active_config" "$HOME/.config/gcloud/active_config"
link_file "$ROOT/config/gcloud/configurations/config_default" "$HOME/.config/gcloud/configurations/config_default"
link_file "$ROOT/config/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"

mkdir -p "$HOME/.config/op"
if [ ! -e "$HOME/.config/op/dotfiles.env" ]; then
  cp "$ROOT/config/op/env.example" "$HOME/.config/op/dotfiles.env"
  printf 'created %s from 1Password reference template\n' "$HOME/.config/op/dotfiles.env"
fi

mkdir -p "$HOME/.config/brewfile"
link_file "$ROOT/brew/Brewfile" "$HOME/.config/brewfile/Brewfile"

if [ -d "$BACKUP_DIR" ]; then
  printf 'backups saved in %s\n' "$BACKUP_DIR"
fi
