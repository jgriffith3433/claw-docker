#!/bin/bash
# Simple retry wrapper for Unity MCP calls via mcporter
# Usage: unity-call <tool_name> [args...]
# Example: unity-call get_console_logs logType=error
#
# Retries up to 3 times with 5s delay between attempts.
# Handles the flaky connection during domain reloads.

MAX_RETRIES=3
RETRY_DELAY=5
TOOL="$1"
shift

if [ -z "$TOOL" ]; then
    echo "Usage: unity-call <tool_name> [args...]"
    exit 1
fi

for attempt in $(seq 1 $MAX_RETRIES); do
    result=$(mcporter call unity "$TOOL" "$@" 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo "$result"
        exit 0
    fi
    
    # Check if it's a connection error (worth retrying)
    if echo "$result" | grep -qE "Connection closed|ECONNREFUSED|offline|timed out"; then
        if [ $attempt -lt $MAX_RETRIES ]; then
            echo "[unity-call] Attempt $attempt failed (connection). Retrying in ${RETRY_DELAY}s..." >&2
            sleep $RETRY_DELAY
            continue
        fi
    fi
    
    # Non-connection error or last attempt — return as-is
    echo "$result"
    exit $exit_code
done

echo "[unity-call] All $MAX_RETRIES attempts failed." >&2
exit 1
