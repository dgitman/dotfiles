#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/auto-sync.log"

mkdir -p "$LOG_DIR"
cd "$ROOT"

timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*" >>"$LOG_FILE"
}

"/scripts/scan-secrets.sh" >>"" 2>&1

if ! git remote get-url origin >/dev/null 2>&1; then
  log "skipped: no origin remote configured"
  exit 0
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  git add -A

  if ! git diff --cached --quiet; then
    git commit -m "Update dotfiles"
    log "committed local dotfile changes"
  fi
fi

if git status --porcelain | grep -q .; then
  log "skipped push: working tree still has uncommitted changes"
  exit 0
fi

git pull --rebase --autostash origin main >>"$LOG_FILE" 2>&1
git push origin main >>"$LOG_FILE" 2>&1
log "synced dotfiles"
