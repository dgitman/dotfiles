#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PATTERN='-----BEGIN [A-Z ]*PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9_]{36,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[0-9A-Za-z-]{10,}|(password|passwd|token|secret|api[_-]?key)[[:space:]]*[:=][[:space:]]*[^[:space:]#]+'
EXCLUDES=(
  --glob '!.git/**'
  --glob '!logs/**'
  --glob '!brew/Brewfile'
)
FORBIDDEN_PATHS=(
  'config/gh/hosts.yml'
  'config/gcloud/access_tokens.db'
  'config/gcloud/credentials.db'
  'config/gcloud/default_configs.db'
  'config/gcloud/legacy_credentials/*'
  'config/gcloud/logs/*'
  'config/gcloud/virtenv/*'
  'config/op/dotfiles.env'
  'config/op/dotfiles-files.env'
)

filter_allowed_matches() {
  grep -v '=[[:space:]]*op://' || true
}

scan_for_forbidden_paths() {
  local forbidden=0
  local path
  local pattern

  while read -r path; do
    for pattern in "${FORBIDDEN_PATHS[@]}"; do
      case "$path" in
        $pattern)
          printf 'Forbidden credential-bearing path is tracked: %s\n' "$path" >&2
          forbidden=1
          ;;
      esac
    done
  done < <(git ls-files)

  return "$forbidden"
}

scan_content() {
  local tmp
  tmp="$(mktemp)"

  rg --hidden --no-ignore --line-number --ignore-case --regexp "$PATTERN" "${EXCLUDES[@]}" . | filter_allowed_matches >"$tmp" || true

  if [ -s "$tmp" ]; then
    cat "$tmp"
    rm -f "$tmp"
    return 1
  fi

  rm -f "$tmp"
  return 0
}

scan_worktree() {
  local failed=0

  scan_for_forbidden_paths || failed=1
  scan_content || failed=1

  return "$failed"
}

scan_history() {
  local found=0
  local commit
  local tmp
  local filtered
  tmp="$(mktemp)"
  filtered="$(mktemp)"

  while read -r commit; do
    if git grep -I -n -E "$PATTERN" "$commit" -- . ':(exclude)brew/Brewfile' ':(exclude)logs/**' >"$tmp" 2>/dev/null; then
      filter_allowed_matches <"$tmp" >"$filtered"
      if [ -s "$filtered" ]; then
        printf 'Potential secret in commit %s:\n' "$commit"
        cat "$filtered"
        found=1
      fi
    fi
  done < <(git rev-list --all)

  rm -f "$tmp" "$filtered"
  return "$found"
}

case "${1:-}" in
  --history)
    if scan_history; then
      printf 'Secret scan passed for Git history.\n'
    else
      printf 'Secret scan failed for Git history.\n' >&2
      exit 1
    fi
    ;;
  *)
    if scan_worktree; then
      printf 'Secret scan passed.\n'
    else
      printf 'Secret scan failed. Review the matches above before committing or pushing.\n' >&2
      exit 1
    fi
    ;;
esac
