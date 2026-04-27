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

scan_worktree() {
  rg --hidden --no-ignore --line-number --ignore-case --regexp "$PATTERN" "${EXCLUDES[@]}" .
}

scan_history() {
  local found=0
  local commit

  while read -r commit; do
    if git grep -I -n -E "$PATTERN" "$commit" -- . ':(exclude)brew/Brewfile' ':(exclude)logs/**' >/tmp/dotfiles-secret-scan.$$ 2>/dev/null; then
      printf 'Potential secret in commit %s:\n' "$commit"
      cat /tmp/dotfiles-secret-scan.$$
      found=1
    fi
  done < <(git rev-list --all)

  rm -f /tmp/dotfiles-secret-scan.$$
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
      printf 'Secret scan failed. Review the matches above before committing or pushing.\n' >&2
      exit 1
    fi

    printf 'Secret scan passed.\n'
    ;;
esac
