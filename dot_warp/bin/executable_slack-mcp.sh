#!/bin/bash
# Warp Slack MCP: resolve 1Password secrets, then run mcp-remote with static OAuth (no DCR).
set -euo pipefail

CLIENT_ID="$(op read "op://5muo7u2aqulocq4t75j7ykbw2u/gsdcuv36e5755pehj3ddswmo5m/client_id")"
CLIENT_SECRET="$(op read "op://5muo7u2aqulocq4t75j7ykbw2u/gsdcuv36e5755pehj3ddswmo5m/client_secret")"
PORT="${SLACK_MCP_OAUTH_PORT:-3456}"

# Slack app Redirect URL must include:
#   http://127.0.0.1:3456/oauth/callback

INFO="$(CLIENT_ID="$CLIENT_ID" CLIENT_SECRET="$CLIENT_SECRET" python3 - <<'PY'
import json, os
print(json.dumps({
    "client_id": os.environ["CLIENT_ID"],
    "client_secret": os.environ["CLIENT_SECRET"],
}))
PY
)"
META='{"scope":"channels:history channels:read users:read search:read.public"}'

exec npx -y mcp-remote@latest \
  "https://mcp.slack.com/mcp" \
  "$PORT" \
  --host "127.0.0.1" \
  --static-oauth-client-info "$INFO" \
  --static-oauth-client-metadata "$META"
