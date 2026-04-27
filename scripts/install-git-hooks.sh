#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_DIR="$ROOT/.git/hooks"

mkdir -p "$HOOK_DIR"
ln -sf "$ROOT/hooks/pre-commit" "$HOOK_DIR/pre-commit"
ln -sf "$ROOT/hooks/pre-push" "$HOOK_DIR/pre-push"

printf 'installed dotfiles Git hooks\n'
