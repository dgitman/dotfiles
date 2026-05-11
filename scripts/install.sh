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
link_file "$ROOT/git/.gitignore_global" "$HOME/.gitignore_global"

# Ensure ~/.local/bin is first on PATH (login shells via ~/.zprofile).
if ! grep -Fqx 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zprofile" 2>/dev/null; then
  printf '\n# Prefer XDG-style personal bin\nexport PATH=\"$HOME/.local/bin:$PATH\"\n' >>"$HOME/.zprofile"
  printf 'updated %s to include ~/.local/bin on PATH\n' "$HOME/.zprofile"
fi


ensure_local_bin_symlink() {
  local target="$HOME/dotfiles/bin"
  local link="$HOME/.local/bin"

  mkdir -p "$HOME/.local"

  if [ -L "$link" ]; then
    if [ "$(readlink "$link")" = "$target" ]; then
      return
    fi
    rm -f "$link"
  elif [ -e "$link" ]; then
    local backup="$HOME/.local/bin.backup.$(date +%Y%m%d-%H%M%S)"
    mv "$link" "$backup"
  fi

  ln -s "$target" "$link"
  printf 'linked %s -> %s\n' "$link" "$target"
}

ensure_local_bin_symlink

