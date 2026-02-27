#!/bin/sh
set -e

CONFIG_DIR="$HOME/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
SEED_FILE="/opt/openclaw/openclaw.seed.json"

# ---------------------------------------------------------------------------
# Git configuration (line endings, credentials, LFS)
# ---------------------------------------------------------------------------

# Handle CRLF ↔ LF automatically (Windows volumes mount files with CRLF)
git config --global core.autocrlf true

# Skip LFS smudge by default (avoids slow downloads on mounted volumes).
# Individual repos can override with: git lfs install --local
if [ "${GIT_LFS_SKIP_SMUDGE:-1}" = "1" ]; then
  export GIT_LFS_SKIP_SMUDGE=1
fi

# Reduce lock contention on 9p-mounted volumes
git config --global core.useBuiltinFSMonitor false

# Set up a credential helper that returns the GitHub PAT from the environment.
# This lets `git push` work without manually injecting tokens into remote URLs.
if [ -n "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
  CRED_HELPER="$HOME/.git-credential-env-helper"
  cat > "$CRED_HELPER" <<'HELPER'
#!/bin/sh
# Reads GITHUB_PERSONAL_ACCESS_TOKEN from env and returns it for any github.com request.
if [ "$1" = "get" ]; then
  while IFS= read -r line; do
    case "$line" in host=github.com*) MATCH=1 ;; esac
  done
  if [ "$MATCH" = "1" ]; then
    echo "protocol=https"
    echo "host=github.com"
    echo "username=x-access-token"
    echo "password=$GITHUB_PERSONAL_ACCESS_TOKEN"
  fi
fi
HELPER
  chmod +x "$CRED_HELPER"
  git config --global credential.helper "$CRED_HELPER"
  echo "[entrypoint] Git credential helper configured (uses GITHUB_PERSONAL_ACCESS_TOKEN)"
fi

# Seed config on first run (if no config exists yet)
if [ ! -f "$CONFIG_FILE" ] && [ -f "$SEED_FILE" ]; then
  mkdir -p "$CONFIG_DIR"
  cp "$SEED_FILE" "$CONFIG_FILE"

  # Inject Telegram bot token from env if set
  if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    node -e "
      const fs = require('fs');
      const cfg = JSON.parse(fs.readFileSync('$CONFIG_FILE','utf8'));
      cfg.channels = cfg.channels || {};
      cfg.channels.telegram = cfg.channels.telegram || {};
      cfg.channels.telegram.botToken = process.env.TELEGRAM_BOT_TOKEN;
      fs.writeFileSync('$CONFIG_FILE', JSON.stringify(cfg, null, 2));
    "
  fi

  echo "[entrypoint] Seeded config from $SEED_FILE"
fi

# Configure MCP servers (GitHub + Unity)
mkdir -p "$HOME/.mcporter"

# Start with empty servers object
MCP_SERVERS=""

# Add GitHub MCP server if PAT is provided
if [ -n "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
  MCP_SERVERS="$MCP_SERVERS
    \"github\": {
      \"command\": \"github-mcp-server\",
      \"args\": [\"stdio\"],
      \"env\": {
        \"GITHUB_PERSONAL_ACCESS_TOKEN\": \"$GITHUB_PERSONAL_ACCESS_TOKEN\"
      }
    }"
  echo "[entrypoint] GitHub MCP server configured"
fi

# Add Unity MCP bridge if host is reachable
if [ -n "$UNITY_MCP_HOST" ]; then
  if [ -n "$MCP_SERVERS" ]; then
    MCP_SERVERS="$MCP_SERVERS,"
  fi
  MCP_SERVERS="$MCP_SERVERS
    \"unity\": {
      \"command\": \"node\",
      \"args\": [\"/opt/mcp-unity/Server~/build/index.js\"],
      \"env\": {
        \"UNITY_HOST\": \"$UNITY_MCP_HOST\",
        \"UNITY_PORT\": \"${UNITY_MCP_PORT:-8090}\"
      }
    }"
  echo "[entrypoint] Unity MCP server configured (host=$UNITY_MCP_HOST:${UNITY_MCP_PORT:-8090})"
fi

# Write the combined mcporter config
if [ -n "$MCP_SERVERS" ]; then
  cat > "$HOME/.mcporter/mcporter.json" <<EOF
{
  "mcpServers": {$MCP_SERVERS
  }
}
EOF
fi

exec "$@"
