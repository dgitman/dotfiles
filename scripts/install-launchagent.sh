#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$HOME/Library/LaunchAgents" "$ROOT/logs"

for plist in "$ROOT/launchd/"*.plist; do
  plist_name="$(basename "$plist")"
  target="$HOME/Library/LaunchAgents/$plist_name"

  cp "$plist" "$target"
  launchctl bootout "gui/$UID" "$target" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$UID" "$target"
  printf 'installed %s\n' "$target"
done
