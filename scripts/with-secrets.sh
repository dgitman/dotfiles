#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${DOTFILES_OP_ENV:-$HOME/.config/op/dotfiles.env}"

if ! command -v op >/dev/null 2>&1; then
  printf '1Password CLI is not installed or not on PATH.\n' >&2
  exit 127
fi

if [ ! -f "$ENV_FILE" ]; then
  printf 'Missing %s\n' "$ENV_FILE" >&2
  printf 'Create it from %s/config/op/env.example and use 1Password secret references, not raw values.\n' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" >&2
  exit 1
fi

if [ "$#" -eq 0 ]; then
  exec op run --env-file "$ENV_FILE" -- "$SHELL"
fi

exec op run --env-file "$ENV_FILE" -- "$@"
