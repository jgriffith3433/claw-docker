#!/bin/bash
# Start the persistent Unity MCP Bridge
# This should be called from the Docker entrypoint or manually

BRIDGE_SCRIPT="/home/node/.openclaw/workspace/claw-docker/scripts/unity-bridge.mjs"
BRIDGE_PORT="${UNITY_BRIDGE_PORT:-8091}"
LOG_FILE="/tmp/unity-bridge.log"

# Check if already running
if pgrep -f "unity-bridge.mjs" > /dev/null 2>&1; then
    echo "[unity-bridge] Already running (PID $(pgrep -f unity-bridge.mjs))"
    exit 0
fi

# Start the bridge (must run from mcp-unity dir for module resolution)
cd /opt/mcp-unity/Server~ || exit 1
nohup node "$BRIDGE_SCRIPT" > "$LOG_FILE" 2>&1 &
BRIDGE_PID=$!

echo "[unity-bridge] Started (PID $BRIDGE_PID, port $BRIDGE_PORT)"
echo "[unity-bridge] Log: $LOG_FILE"

# Wait for it to be ready
for i in $(seq 1 10); do
    sleep 1
    if curl -s "http://localhost:${BRIDGE_PORT}/status" > /dev/null 2>&1; then
        STATUS=$(curl -s "http://localhost:${BRIDGE_PORT}/status" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Unity: {d[\"unity\"]}')" 2>/dev/null)
        echo "[unity-bridge] Ready! $STATUS"
        exit 0
    fi
done

echo "[unity-bridge] WARNING: Bridge started but not responding after 10s"
exit 1
