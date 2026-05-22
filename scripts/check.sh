#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/check.log"

mkdir -p "$LOG_DIR"

timestamp() { date "+%Y-%m-%d %H:%M:%S"; }

log() { printf '[%s] %s\n' "$(timestamp)" "$*" >>"$LOG_FILE"; }

log "running dotfiles check"

if output="$("$ROOT/scripts/install.sh" --check 2>&1)"; then
  log "check passed"
  printf '%s\n' "$output" >>"$LOG_FILE"
else
  failures="$(printf '%s\n' "$output" | grep -cE '^(DRIFT|UNLINKED|MISSING|SYMLINK)' || true)"
  log "check FAILED — ${failures} issue(s)"
  printf '%s\n' "$output" >>"$LOG_FILE"
  osascript -e "display notification \"${failures} issue(s) found. Run 'make check' in ~/dotfiles to fix.\" with title \"Dotfiles: drift detected\" sound name \"Basso\"" 2>/dev/null || true
  exit 1
fi
