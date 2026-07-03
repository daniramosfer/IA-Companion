#!/usr/bin/env python3
import os
import glob
import time
import subprocess
import urllib.request
import json

def notify_status(ia_id, name, status):
    data = json.dumps({"id": ia_id, "name": name, "status": status}).encode('utf-8')
    req = urllib.request.Request("http://localhost:50152/status", data=data, headers={'Content-Type': 'application/json'})
    try:
        urllib.request.urlopen(req, timeout=1)
    except:
        pass

def get_latest_antigravity_mtime():
    base_dir = os.path.expanduser("~/.gemini/antigravity/brain")
    pattern = os.path.join(base_dir, "*", ".system_generated", "logs", "transcript.jsonl")
    files = glob.glob(pattern)
    if not files:
        return 0
    latest_file = max(files, key=os.path.getmtime)
    return os.path.getmtime(latest_file)

def is_claude_cli_working():
    try:
        output = subprocess.check_output(["ps", "-A", "-o", "%cpu,command"], text=True)
        for line in output.split('\n'):
            # Look for node running claude code or the packaged claude-code binary
            if ('node' in line.lower() and 'claude' in line.lower()) or ('/claude-code/' in line.lower()):
                parts = line.strip().split(maxsplit=1)
                if len(parts) >= 2:
                    try:
                        cpu = float(parts[0])
                        # If CPU is above 0.3%, the LLM CLI is actively processing/streaming
                        if cpu >= 0.3:
                            return True
                    except:
                        pass
        return False
    except:
        return False

antigravity_status = "idle"
desktop_status = "idle"
cli_status = "idle"
reported_claude_status = "idle"

claude_log_size = 0
log_file = os.path.expanduser("~/Library/Logs/Claude/main.log")
if os.path.exists(log_file):
    claude_log_size = os.path.getsize(log_file)

# Wait a couple seconds to ensure server is up if launching at login
time.sleep(2)
notify_status("antigravity", "Antigravity", "idle")
notify_status("claude", "Claude", "idle")

while True:
    time.sleep(1)
    
    # 1. Antigravity Check
    ag_mtime = get_latest_antigravity_mtime()
    current_time = time.time()
    
    # If transcript was modified in the last 4 seconds, it's working
    new_ag_status = "working" if (current_time - ag_mtime) < 4 else "idle"
    if new_ag_status != antigravity_status:
        antigravity_status = new_ag_status
        notify_status("antigravity", "Antigravity", antigravity_status)
        
    # 2. Claude Desktop Check
    if os.path.exists(log_file):
        current_size = os.path.getsize(log_file)
        if current_size < claude_log_size:
            claude_log_size = 0 # Log rotated
        if current_size > claude_log_size:
            with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                f.seek(claude_log_size)
                new_lines = f.read()
            claude_log_size = current_size
            
            if "Emitted tool permission request" in new_lines:
                desktop_status = "waiting"
            elif "Sending message to session" in new_lines or "Received permission response" in new_lines:
                desktop_status = "working"
            elif "[Stop hook] Query completed" in new_lines:
                desktop_status = "idle"
                
    # 3. Claude CLI Check
    cli_status = "working" if is_claude_cli_working() else "idle"
    
    # Combined Claude status
    if desktop_status == "waiting":
        final_claude = "waiting"
    elif cli_status == "working" or desktop_status == "working":
        final_claude = "working"
    else:
        final_claude = "idle"
        
    if final_claude != reported_claude_status:
        reported_claude_status = final_claude
        notify_status("claude", "Claude", reported_claude_status)
