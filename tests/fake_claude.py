#!/usr/bin/env python3
"""Stand-in for the `claude` CLI so the backend can be tested without an account.

It mimics `claude -p --input-format stream-json --output-format stream-json`.
Every call appends its argv + stdin message to $FAKE_CLAUDE_LOG.
"""
import json
import os
import sys
import uuid
from pathlib import Path

if "--help" in sys.argv:
    print("--effort --tools --strict-mcp-config --disable-slash-commands --safe-mode")
    sys.exit(0)

msg = json.loads(sys.stdin.readline())
if os.environ.get("FAKE_CLAUDE_LOG"):
    with open(os.environ["FAKE_CLAUDE_LOG"], "a") as log:
        log.write(json.dumps({"argv": sys.argv[1:], "message": msg}) + "\n")

if os.environ.get("FAKE_CLAUDE_FAIL"):
    print(json.dumps({"type": "result", "subtype": "error", "is_error": True,
                      "result": "Invalid API key · Please run /login"}), flush=True)
    sys.exit(1)

session = sys.argv[sys.argv.index("--resume") + 1] if "--resume" in sys.argv else str(uuid.uuid4())
# Write a transcript like Claude Code does, so size/delete logic can be tested.
project = Path(os.environ["CLAUDE_CONFIG_DIR"]) / "projects" / "-tmp-workdir"
project.mkdir(parents=True, exist_ok=True)
with open(project / f"{session}.jsonl", "a") as t:
    t.write(json.dumps(msg) + "\n")


def out(obj):
    print(json.dumps(obj), flush=True)


out({"type": "system", "subtype": "init", "session_id": session})

if "--permission-prompt-tool" in sys.argv:
    # Agent mode: pretend Claude wants to run a command and ask for permission.
    out({"type": "assistant", "parent_tool_use_id": None, "message": {"content": [
        {"type": "tool_use", "name": "Bash", "input": {"command": "ls ~/Downloads"}}]}})
    out({"type": "control_request", "request_id": "req-1", "request": {
        "subtype": "can_use_tool", "tool_name": "Bash", "input": {"command": "ls ~/Downloads"}}})
    reply = json.loads(sys.stdin.readline())
    behavior = reply["response"]["response"]["behavior"]
    if os.environ.get("FAKE_CLAUDE_LOG"):
        with open(os.environ["FAKE_CLAUDE_LOG"], "a") as log:
            log.write(json.dumps({"reply": reply}) + "\n")
    out({"type": "result", "subtype": "success", "is_error": False, "result": f"Command was {behavior}ed.",
         "session_id": session, "total_cost_usd": 0, "usage": {"input_tokens": 50, "output_tokens": 5}})
    sys.exit(0)
out({"type": "stream_event", "event": {"type": "content_block_start", "content_block": {"type": "thinking"}}})
out({"type": "stream_event", "event": {"type": "content_block_delta", "delta": {"type": "thinking_delta", "thinking": "hm"}}})
out({"type": "stream_event", "event": {"type": "content_block_start", "content_block": {"type": "text"}}})
has_image = any(b.get("type") == "image" for b in msg["message"]["content"])
answer = ["Hello", " there", "!" if not has_image else " I see an image."]
for part in answer:
    out({"type": "stream_event", "event": {"type": "content_block_delta", "delta": {"type": "text_delta", "text": part}}})
    if os.environ.get("FAKE_CLAUDE_SLOW"):
        import time
        time.sleep(2)
out({"type": "assistant", "message": {"content": [{"type": "text", "text": "".join(answer)}]}})
# Like Claude Code 2.1.28x: subscription usage with every answer (utilization 0-1, resetsAt in seconds).
import time as _t
out({"type": "rate_limit_event", "rate_limit_info": {
    "status": "allowed", "resetsAt": int(_t.time()) + 3600, "rateLimitType": "five_hour",
    "unifiedWindows": {"five_hour": {"utilization": 0.235, "resetsAt": int(_t.time()) + 3600},
                       "seven_day": {"utilization": 0.41, "resetsAt": int(_t.time()) + 86400}}}})
out({"type": "result", "subtype": "success", "is_error": False, "result": "".join(answer),
     "session_id": session, "total_cost_usd": 0.0012,
     "usage": {"input_tokens": 120, "output_tokens": 8}})
