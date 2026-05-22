#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$HOME/Library/LaunchAgents" "$ROOT/logs"

for plist in "$ROOT/launchd/"*.plist; do
  plist_name="$(basename "$plist")"
  target="$HOME/Library/LaunchAgents/$plist_name"

  cp "$plist" "$target"
  # unload handles both old (launchctl load) and new (bootstrap) registrations;
  # bootstrap alone fails with I/O error 5 if the agent was previously loaded
  # via the older API.
  launchctl unload "$target" 2>/dev/null || true
  launchctl load -w "$target"
  printf 'installed %s\n' "$target"
done
