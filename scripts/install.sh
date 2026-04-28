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
link_file "$ROOT/dotfiles/.warp" "$HOME/.warp"
link_file "$ROOT/git/.gitconfig" "$HOME/.gitconfig"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
link_file "$ROOT/ssh/config" "$HOME/.ssh/config"
chmod 600 "$ROOT/ssh/config"

link_file "$ROOT/config/gh/config.yml" "$HOME/.config/gh/config.yml"
link_file "$ROOT/config/gcloud/active_config" "$HOME/.config/gcloud/active_config"
link_file "$ROOT/config/gcloud/configurations/config_default" "$HOME/.config/gcloud/configurations/config_default"
link_file "$ROOT/config/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
link_file "$ROOT/config/cursor/settings.json" "$HOME/Library/Application Support/Cursor/User/settings.json"
link_file "$ROOT/config/cursor/keybindings.json" "$HOME/Library/Application Support/Cursor/User/keybindings.json"
link_file "$ROOT/config/claude/settings.json" "$HOME/.claude/settings.json"
link_file "$ROOT/config/claude/plugins/config.json" "$HOME/.claude/plugins/config.json"
link_file "$ROOT/config/claude/policy-limits.json" "$HOME/.claude/policy-limits.json"
link_file "$ROOT/config/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
link_file "$ROOT/config/codex/config.toml" "$HOME/.codex/config.toml"

mkdir -p "$HOME/.rbenv"
link_file "$ROOT/config/rbenv/version" "$HOME/.rbenv/version"

mkdir -p "$HOME/.config/op"
if [ ! -e "$HOME/.config/op/dotfiles.env" ]; then
  cp "$ROOT/config/op/env.example" "$HOME/.config/op/dotfiles.env"
  printf 'created %s from 1Password reference template\n' "$HOME/.config/op/dotfiles.env"
fi

if [ ! -e "$HOME/.config/op/dotfiles-files.env" ]; then
  cp "$ROOT/config/op/files.example" "$HOME/.config/op/dotfiles-files.env"
  printf 'created %s from 1Password file reference template\n' "$HOME/.config/op/dotfiles-files.env"
fi

mkdir -p "$HOME/.config/brewfile"
link_file "$ROOT/brew/Brewfile" "$HOME/.config/brewfile/Brewfile"

if [ -d "$BACKUP_DIR" ]; then
  printf 'backups saved in %s\n' "$BACKUP_DIR"
fi
