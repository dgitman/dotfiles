#!/usr/bin/env bash
set -euo pipefail

VAULT="${DOTFILES_OP_VAULT:-Private}"
ENV_FILE="${DOTFILES_OP_FILES_ENV:-$HOME/.config/op/dotfiles-files.env}"
TAG="${DOTFILES_OP_TAG:-dotfiles}"

if ! command -v op >/dev/null 2>&1; then
  printf '1Password CLI is not installed or not on PATH.\n' >&2
  exit 127
fi

mkdir -p "$(dirname "$ENV_FILE")"
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"

upsert_env_ref() {
  local var_name="$1"
  local ref="$2"
  local tmp
  tmp="$(mktemp)"

  grep -v -E "^#?[[:space:]]*${var_name}=" "$ENV_FILE" >"$tmp" || true
  printf '%s="%s"\n' "$var_name" "$ref" >>"$tmp"
  mv "$tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

store_document() {
  local var_name="$1"
  local source="$2"
  local title="$3"
  local file_name="$4"

  if [ ! -f "$source" ]; then
    return 0
  fi

  if op item get "$title" --vault "$VAULT" >/dev/null 2>&1; then
    op document edit "$title" "$source" --file-name "$file_name" --tags "$TAG" --vault "$VAULT" >/dev/null
    printf 'updated %s in 1Password\n' "$title"
  else
    op document create "$source" --title "$title" --file-name "$file_name" --tags "$TAG" --vault "$VAULT" >/dev/null
    printf 'created %s in 1Password\n' "$title"
  fi

  upsert_env_ref "$var_name" "op://$VAULT/$title/$file_name"
}

store_document GH_HOSTS_YML "$HOME/.config/gh/hosts.yml" "GitHub CLI hosts.yml" "hosts.yml"
store_document CLAUDE_JSON "$HOME/.claude.json" "Claude config" ".claude.json"
store_document CODEX_AUTH_JSON "$HOME/.codex/auth.json" "Codex auth.json" "auth.json"
store_document GCLOUD_APPLICATION_DEFAULT_CREDENTIALS_JSON "$HOME/.config/gcloud/application_default_credentials.json" "Google ADC JSON" "application_default_credentials.json"

printf 'updated %s\n' "$ENV_FILE"
