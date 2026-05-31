#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
FAILED=0

MODE="install"
if [ "${1:-}" = "--check" ]; then
  MODE="check"
elif [ -n "${1:-}" ]; then
  printf 'Usage: %s [--check]\n' "$0" >&2
  exit 1
fi

# ── helpers ────────────────────────────────────────────────────────────────────

_pass() { printf 'ok        %s\n'         "$1"; }
_fail() { printf '%-9s %s\n' "$1" "$2"; FAILED=1; }

link_file() {
  local source="$1"
  local target="$2"

  if [ "$MODE" = "check" ]; then
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
      _pass "$target"
    elif [ -L "$target" ]; then
      _fail "DRIFT"    "$target -> $(readlink "$target") (expected -> $source)"
    elif [ -e "$target" ]; then
      _fail "UNLINKED" "$target (regular file; expected symlink -> $source)"
    else
      _fail "MISSING"  "$target (expected symlink -> $source)"
    fi
    return
  fi

  mkdir -p "$(dirname "$target")"

  if [ -e "$target" ] || [ -L "$target" ]; then
    mkdir -p "$BACKUP_DIR$(dirname "$target")"
    mv "$target" "$BACKUP_DIR$target"
  fi

  ln -s "$source" "$target"
  printf 'linked    %s -> %s\n' "$target" "$source"
}

# For files that contain $HOME placeholders — expands variables at deploy time
# rather than symlinking, so the live file contains literal paths.
deploy_template() {
  local source="$1"
  local target="$2"

  if [ "$MODE" = "check" ]; then
    if [ -L "$target" ]; then
      _fail "SYMLINK"  "$target (should be a deployed copy, not a symlink)"
    elif [ -f "$target" ]; then
      _pass "$target"
    else
      _fail "MISSING"  "$target (expected deployed copy from $source)"
    fi
    return
  fi

  mkdir -p "$(dirname "$target")"

  if [ -e "$target" ] || [ -L "$target" ]; then
    mkdir -p "$BACKUP_DIR$(dirname "$target")"
    mv "$target" "$BACKUP_DIR$target"
  fi

  envsubst < "$source" > "$target"
  printf 'deployed  %s (from %s)\n' "$target" "$source"
}

# ── declarations ───────────────────────────────────────────────────────────────

link_file "$ROOT/dotfiles/.zshrc"    "$HOME/.zshrc"
link_file "$ROOT/dotfiles/.zprofile" "$HOME/.zprofile"
link_file "$ROOT/git/.gitconfig"         "$HOME/.gitconfig"
link_file "$ROOT/git/.gitignore_global"  "$HOME/.gitignore_global"

link_file "$ROOT/ssh/config" "$HOME/.ssh/config"

link_file "$ROOT/config/gh/config.yml" "$HOME/.config/gh/config.yml"

link_file "$ROOT/config/gcloud/active_config"                 "$HOME/.config/gcloud/active_config"
link_file "$ROOT/config/gcloud/configurations/config_default" "$HOME/.config/gcloud/configurations/config_default"

link_file "$ROOT/config/cursor/settings.json"    "$HOME/Library/Application Support/Cursor/User/settings.json"
link_file "$ROOT/config/cursor/keybindings.json" "$HOME/Library/Application Support/Cursor/User/keybindings.json"

link_file "$ROOT/config/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
link_file "$ROOT/config/vscode/argv.json"     "$HOME/.vscode/argv.json"

link_file "$ROOT/config/thefuck/settings.py" "$HOME/.config/thefuck/settings.py"

link_file "$ROOT/config/codex/config.toml"        "$HOME/.codex/config.toml"
link_file "$ROOT/config/codex/AGENTS.md"           "$HOME/.codex/AGENTS.md"
link_file "$ROOT/config/codex/browser/config.toml" "$HOME/.codex/browser/config.toml"

link_file "$ROOT/config/claude/settings.json"       "$HOME/.claude/settings.json"
link_file "$ROOT/config/claude/policy-limits.json"  "$HOME/.claude/policy-limits.json"
link_file "$ROOT/config/claude/plugins/config.json" "$HOME/.claude/plugins/config.json"

# settings.local.json uses $HOME placeholders — copy with envsubst rather than symlink
deploy_template "$ROOT/config/claude/settings.local.json" "$HOME/.claude/settings.local.json"

# ── install-only steps ─────────────────────────────────────────────────────────

if [ "$MODE" = "check" ]; then
  # Validate ~/.local/bin -> ~/dotfiles/bin
  local_bin="$HOME/.local/bin"
  expected="$HOME/dotfiles/bin"
  if [ -L "$local_bin" ] && [ "$(readlink "$local_bin")" = "$expected" ]; then
    _pass "$local_bin"
  elif [ -L "$local_bin" ]; then
    _fail "DRIFT"   "$local_bin -> $(readlink "$local_bin") (expected -> $expected)"
  elif [ -e "$local_bin" ]; then
    _fail "UNLINKED" "$local_bin (regular directory; expected symlink -> $expected)"
  else
    _fail "MISSING"  "$local_bin (expected symlink -> $expected)"
  fi

  printf '\n'
  if [ "$FAILED" -eq 0 ]; then
    printf 'All %d declared links and templates are in order.\n' \
      "$(grep -c 'link_file\|deploy_template' "$0")"
  else
    printf 'Issues found — run ./scripts/install.sh to repair.\n' >&2
    exit 1
  fi
  exit 0
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
  printf 'linked    %s -> %s\n' "$link" "$target"
}

ensure_local_bin_symlink
