#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${DOTFILES_OP_FILES_ENV:-$HOME/.config/op/dotfiles-files.env}"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

if ! command -v op >/dev/null 2>&1; then
  printf '1Password CLI is not installed or not on PATH.\n' >&2
  exit 127
fi

if [ ! -f "$ENV_FILE" ]; then
  printf 'Missing %s\n' "$ENV_FILE" >&2
  printf 'Create it from %s/config/op/files.example and use 1Password secret references, not raw values.\n' "$ROOT" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

restore_file() {
  local var_name="$1"
  local target="$2"
  local mode="$3"
  local ref="${!var_name:-}"

  if [ -z "$ref" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$target")"

  if [ -e "$target" ] || [ -L "$target" ]; then
    mkdir -p "$BACKUP_DIR$(dirname "$target")"
    mv "$target" "$BACKUP_DIR$target"
  fi

  op read "$ref" >"$target"
  chmod "$mode" "$target"
  printf 'restored %s from %s\n' "$target" "$var_name"
}

restore_file GH_HOSTS_YML "$HOME/.config/gh/hosts.yml" 600
restore_file CLAUDE_JSON "$HOME/.claude.json" 600
restore_file CODEX_AUTH_JSON "$HOME/.codex/auth.json" 600
restore_file GCLOUD_APPLICATION_DEFAULT_CREDENTIALS_JSON "$HOME/.config/gcloud/application_default_credentials.json" 600

if [ -d "$BACKUP_DIR" ]; then
  printf 'backups saved in %s\n' "$BACKUP_DIR"
fi
