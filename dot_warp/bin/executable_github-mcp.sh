#!/bin/bash
# Warp GitHub MCP: GitHub remote does not support DCR — use a PAT via mcp-remote.
# Token supplied by the chezmoi-rendered MCP config (or the caller).
set -euo pipefail

TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN:-${GH_TOKEN:-}}"

if [[ -z "${TOKEN}" ]]; then
  echo "github-mcp.sh: no GitHub PAT found (set GITHUB_PERSONAL_ACCESS_TOKEN or GH_TOKEN)" >&2
  exit 1
fi

exec npx -y mcp-remote@latest \
  "https://api.githubcopilot.com/mcp/" \
  --header "Authorization: Bearer ${TOKEN}"
