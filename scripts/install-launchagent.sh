#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST_NAME="com.dgitman.dotfiles.autosync.plist"
SOURCE="$ROOT/launchd/$PLIST_NAME"
TARGET="$HOME/Library/LaunchAgents/$PLIST_NAME"

mkdir -p "$HOME/Library/LaunchAgents" "$ROOT/logs"
cp "$SOURCE" "$TARGET"

launchctl bootout "gui/$UID" "$TARGET" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$UID" "$TARGET"

printf 'installed %s\n' "$TARGET"
