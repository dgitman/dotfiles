#!/bin/bash
# Warp GitHub MCP: GitHub remote does not support DCR — use a PAT via mcp-remote.
# Token sources (first match wins):
#   1) GITHUB_PERSONAL_ACCESS_TOKEN / GH_TOKEN env
#   2) op read "$GITHUB_PAT_OP_REF"
#      Default uses item UUID — op://Private/GitHub/API Key is ambiguous
#      (another item titled "Github" in Private).
set -euo pipefail

TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN:-${GH_TOKEN:-}}"
if [[ -z "${TOKEN}" ]]; then
  OP_REF="${GITHUB_PAT_OP_REF:-op://Private/ilisfoloivekdguzpnjepypsbi/API Key}"
  TOKEN="$(op read "$OP_REF")"
fi

if [[ -z "${TOKEN}" ]]; then
  echo "github-mcp.sh: no GitHub PAT found (set GITHUB_PERSONAL_ACCESS_TOKEN or GITHUB_PAT_OP_REF)" >&2
  exit 1
fi

exec npx -y mcp-remote@latest \
  "https://api.githubcopilot.com/mcp/" \
  --header "Authorization: Bearer ${TOKEN}"
