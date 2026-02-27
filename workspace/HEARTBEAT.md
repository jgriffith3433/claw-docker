# Heartbeat

## Status Check Routine

When asked "status" or "what's going on", report:

1. **Unity Editor** — Can you reach it via MCP? Any console errors?
2. **Projects** — Are the mounted volumes accessible? Quick `ls` check.
3. **Last build** — What's the current version in `Game/`? When was it last modified?
4. **MCP servers** — Run `mcporter list` to confirm GitHub and Unity MCP are running.

## Health Commands

```bash
# Check mounted projects
ls /home/node/.openclaw/workspace/sickofitgame-unity/Assets/
ls /home/node/.openclaw/workspace/sickofitgame-website/Game/

# Check current game version
ls /home/node/.openclaw/workspace/sickofitgame-website/Game/ | grep -E '^v[0-9]+$'

# Check MCP servers
mcporter list

# Check Unity MCP connection
mcporter list unity-mcp
```
