#!/bin/bash

# Configuration
CLAUDE_LOG="$HOME/Library/Logs/Claude/main.log"
ANTIGRAVITY_DIR="$HOME/.gemini/antigravity/brain"
API_URL="http://localhost:50152/status"

# State variables
AG_STATUS="idle"
CLAUDE_STATUS="idle"

# Helper to send status
send_status() {
    local id=$1
    local name=$2
    local status=$3
    curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d "{\"id\": \"$id\", \"name\": \"$name\", \"status\": \"$status\"}" > /dev/null
}

# Initial states
sleep 2 # Wait for server
send_status "antigravity" "Antigravity" "idle"
send_status "claude" "Claude" "idle"

# Antigravity watcher (background loop)
watch_antigravity() {
    while true; do
        sleep 2
        # Get the most recently modified transcript file
        LATEST_FILE=$(ls -t "$ANTIGRAVITY_DIR"/*/.system_generated/logs/transcript.jsonl 2>/dev/null | head -n 1)
        
        NEW_STATUS="idle"
        if [ -n "$LATEST_FILE" ]; then
            # Get modified time in seconds
            MTIME=$(stat -f %m "$LATEST_FILE")
            NOW=$(date +%s)
            DIFF=$((NOW - MTIME))
            
            # If modified in the last 15 seconds, consider it working
            if [ $DIFF -lt 15 ]; then
                NEW_STATUS="working"
            fi
        fi
        
        if [ "$NEW_STATUS" != "$AG_STATUS" ]; then
            AG_STATUS=$NEW_STATUS
            send_status "antigravity" "Antigravity" "$AG_STATUS"
        fi
    done
}

watch_antigravity &

# Claude watcher (main loop)
# Note: we use tail -F which is instantly responsive
if [ ! -f "$CLAUDE_LOG" ]; then
    touch "$CLAUDE_LOG"
fi

tail -F "$CLAUDE_LOG" | while read -r line; do
    if echo "$line" | grep -q "Emitted tool permission request"; then
        send_status "claude" "Claude" "waiting"
    elif echo "$line" | grep -q "Received permission response"; then
        send_status "claude" "Claude" "working"
    elif echo "$line" | grep -q "Sending message to session"; then
        send_status "claude" "Claude" "working"
    elif echo "$line" | grep -q "\[Stop hook\] Query completed"; then
        send_status "claude" "Claude" "idle"
    fi
done
