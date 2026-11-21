"""Backend tests. Run with:  python3 -m unittest discover tests"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BACKEND = ROOT / "DuxAI" / "backend" / "duxai.py"
FAKE = Path(__file__).resolve().parent / "fake_claude.py"

# 1x1 transparent PNG
PNG = bytes.fromhex(
    "89504e470d0a1a0a0000000d4948445200000001000000010806000000"
    "1f15c4890000000d49444154789c6360000002000154a24f5d0000000049454e44ae426082")


class BackendTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        tmp = Path(self.tmp.name)
        bin_dir = tmp / "bin"
        bin_dir.mkdir()
        (bin_dir / "claude").symlink_to(FAKE)
        os.chmod(FAKE, 0o755)
        self.log = tmp / "calls.jsonl"
        self.env = dict(os.environ, XDG_DATA_HOME=str(tmp / "data"), CLAUDE_CONFIG_DIR=str(tmp / "claude"),
                        PATH=f"{bin_dir}:{os.environ['PATH']}", FAKE_CLAUDE_LOG=str(self.log), HOME=str(tmp))
        self.data = tmp / "data" / "dux-ai"

    def tearDown(self):
        self.tmp.cleanup()

    def run_backend(self, *args, env=None):
        proc = subprocess.run([sys.executable, str(BACKEND), *args], capture_output=True, text=True,
                              env=env or self.env, timeout=30)
        return [json.loads(line) for line in proc.stdout.splitlines() if line.strip()]

    def calls(self):
        return [json.loads(l) for l in self.log.read_text().splitlines()]

    def test_new_chat_streams_and_saves(self):
        events = self.run_backend("ask", "--model", "haiku", "--effort", "low", "--", "Hi Claude")
        types = [e["type"] for e in events]
        self.assertEqual(types[0], "start")
        self.assertIn("status", types)
        self.assertEqual("".join(e["text"] for e in events if e["type"] == "text"), "Hello there!")
        done = events[-1]
        self.assertEqual(done["type"], "done")
        chat = json.loads((self.data / "chats" / f"{done['chat']}.json").read_text())
        self.assertEqual(chat["title"], "Hi Claude")
        self.assertEqual([m["role"] for m in chat["messages"]], ["user", "assistant"])
        self.assertEqual(done["tokens"]["total"], 128)   # fake claude: 120 in + 8 out
        self.assertEqual(done["tokens"]["last"]["output"], 8)
        self.assertTrue(chat["session_id"])

        argv = self.calls()[0]["argv"]
        self.assertIn("--system-prompt", argv)
        self.assertEqual(argv[argv.index("--tools") + 1], "")       # no tools -> fewer tokens
        self.assertEqual(argv[argv.index("--effort") + 1], "low")
        self.assertIn("--safe-mode", argv)
        self.assertNotIn("--resume", argv)

    def test_follow_up_resumes_session(self):
        first = self.run_backend("ask", "--", "one")[-1]
        self.run_backend("ask", "--chat", first["chat"], "--model", "opus", "--", "two")
        second_argv = self.calls()[1]["argv"]
        chat = json.loads((self.data / "chats" / f"{first['chat']}.json").read_text())
        self.assertEqual(second_argv[second_argv.index("--resume") + 1], chat["session_id"])
        self.assertEqual(second_argv[second_argv.index("--model") + 1], "opus")
        self.assertEqual(len(chat["messages"]), 4)

    def test_image_is_sent_as_content_block(self):
        img = Path(self.tmp.name) / "shot.png"
        img.write_bytes(PNG)
        done = self.run_backend("ask", "--image", str(img), "--", "")[-1]
        self.assertIn("image", done["text"])
        content = self.calls()[0]["message"]["message"]["content"]
        self.assertEqual(content[0]["type"], "image")
        self.assertEqual(content[1]["text"], "What is this?")

    def test_quote_is_wrapped_and_saved(self):
        done = self.run_backend("ask", "--quote=E = mc^2", "--", "")[-1]
        text = self.calls()[0]["message"]["message"]["content"][0]["text"]
        self.assertIn("<selected_text>\nE = mc^2\n</selected_text>", text)
        chat = json.loads((self.data / "chats" / f"{done['chat']}.json").read_text())
        self.assertEqual(chat["messages"][0]["quote"], "E = mc^2")
        self.assertEqual(chat["title"], "E = mc^2")

    def test_web_flag_enables_only_web_tools(self):
        self.run_backend("ask", "--web", "--", "news?")
        argv = self.calls()[0]["argv"]
        self.assertEqual(argv[argv.index("--tools") + 1], "WebSearch,WebFetch")

    def test_usage_limits_are_reported_and_remembered(self):
        events = self.run_backend("ask", "--", "hi")
        limits = [e for e in events if e["type"] == "limits"][-1]["limits"]
        self.assertEqual(limits["five_hour"]["pct"], 23.5)
        self.assertEqual(limits["seven_day"]["pct"], 41.0)
        saved = self.run_backend("limits")[-1]["limits"]
        self.assertEqual(saved["five_hour"]["pct"], 23.5)

    def test_math_is_found_but_not_money_or_code(self):
        mod = self._module()
        pieces = mod.split_math("Mass $m$, $$\\sum n$$, costs $5 and $10, `$code$`, \\(a^2\\).")
        maths = [p[1:] for p in pieces if p[0] == "math"]
        self.assertEqual(maths, [("m", False), ("\\sum n", True), ("a^2", False)])

    def test_math_is_drawn_for_the_chat(self):
        mod = self._module()
        try:
            import ziamath  # noqa: F401
        except ImportError:
            self.skipTest("ziamath not installed")
        pieces = mod.render_math("So $E=mc^2$.", "#ffffff,15,8")
        self.assertEqual(pieces[0], {"t": "So "})
        self.assertEqual(pieces[1]["m"], "E=mc^2")
        self.assertTrue(pieces[1]["src"].endswith(".svg"))
        self.assertIsNone(mod.render_math("No math, just $5.", "#ffffff,15,8"))

    def _module(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("duxai_m", BACKEND)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod

    def test_limits_parsing(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("duxai", BACKEND)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        # older format: one window, utilization only near the limit, resetsAt in ms
        self.assertEqual(mod.parse_limits({"rateLimitType": "five_hour", "utilization": 0.85, "resetsAt": 1790000000000}),
                         {"five_hour": {"pct": 85.0, "resets_at": 1790000000}})
        self.assertEqual(mod.parse_limits({"status": "allowed", "rateLimitType": "five_hour", "resetsAt": 1}), {})

    def test_login_error_is_friendly(self):
        env = dict(self.env, FAKE_CLAUDE_FAIL="1")
        events = self.run_backend("ask", "--", "hi", env=env)
        self.assertEqual(events[-1]["type"], "error")
        self.assertIn("/login", events[-1]["message"])

    def test_list_size_and_delete(self):
        a = self.run_backend("ask", "--", "first")[-1]["chat"]
        self.run_backend("ask", "--", "second")
        listing = self.run_backend("list")[-1]
        self.assertEqual(len(listing["chats"]), 2)
        self.assertGreater(listing["bytes"], 0)

        loaded = self.run_backend("load", a)[-1]
        self.assertEqual(loaded["chat"]["id"], a)
        self.assertEqual(loaded["tokens"]["total"], 128)
        self.assertEqual(listing["chats"][0]["tokens"], 128)
        session = loaded["chat"]["session_id"]
        transcripts = list((Path(self.env["CLAUDE_CONFIG_DIR"]) / "projects").glob(f"*/{session}.jsonl"))
        self.assertEqual(len(transcripts), 1)

        after = self.run_backend("delete", a)[-1]
        self.assertEqual(len(after["chats"]), 1)
        self.assertFalse(transcripts[0].exists())   # Claude Code transcript removed too

        empty = self.run_backend("delete", "all")[-1]
        self.assertEqual(empty["chats"], [])

    def test_logo_is_made_white(self):
        ev = self.run_backend("logo")[-1]
        src = ROOT / "DuxAI" / "assets" / "logo.svg"
        if not src.exists():
            self.assertEqual(ev["path"], "")
            return
        svg = Path(ev["path"]).read_text()
        self.assertNotIn("#D97757", svg)
        self.assertIn('fill="#ffffff"', svg)
        self.assertNotIn('width="1em"', svg)

    def run_agent(self, allow, *extra):
        proc = subprocess.Popen([sys.executable, str(BACKEND), "ask", "--agent", *extra, "--", "list my downloads"],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, env=self.env)
        events = []
        for line in proc.stdout:
            ev = json.loads(line)
            events.append(ev)
            if ev["type"] == "permission":
                proc.stdin.write(json.dumps({"id": ev["id"], "allow": allow}) + "\n")
                proc.stdin.flush()
        proc.wait(timeout=30)
        return events

    def test_agent_permission_allow(self):
        events = self.run_agent(True, "--window=Dolphin - ~/Downloads")
        perm = next(e for e in events if e["type"] == "permission")
        self.assertEqual(perm["summary"], "Run: ls ~/Downloads")
        self.assertIn("Run: ls ~/Downloads", [e["text"] for e in events if e["type"] == "step"])
        self.assertEqual(events[-1]["text"], "Command was allowed.")
        call = self.calls()[0]
        argv = call["argv"]
        self.assertIn("--permission-prompt-tool", argv)
        self.assertNotIn("--safe-mode", argv)            # agent mode uses your normal setup
        rules = json.loads(argv[argv.index("--settings") + 1])["permissions"]
        self.assertIn("Bash(sudo *)", rules["deny"])
        text = call["message"]["message"]["content"][0]["text"]
        self.assertTrue(text.startswith("[Active window: Dolphin - ~/Downloads]"))
        reply = json.loads(self.log.read_text().splitlines()[-1])["reply"]
        self.assertEqual(reply["response"]["request_id"], "req-1")
        self.assertEqual(reply["response"]["response"]["updatedInput"], {"command": "ls ~/Downloads"})

    def test_agent_permission_deny(self):
        events = self.run_agent(False)
        self.assertEqual(events[-1]["text"], "Command was denyed.")   # fake claude's grammar

    def test_permission_rules(self):
        sys.path.insert(0, str(BACKEND.parent))
        import duxai
        r = duxai.permission_rules("trusted", "~/DUX-AI, /data/x", "Documents/KUL", "~/Secret")
        self.assertIn("Edit(~/DUX-AI/**)", r["allow"])
        self.assertIn("Edit(//data/x/**)", r["allow"])
        self.assertIn("Edit(~/Documents/KUL/**)", r["ask"])
        self.assertIn("Read(~/Secret/**)", r["deny"])
        self.assertIn("Bash", duxai.permission_rules("ask_all", "", "", "")["ask"])
        allow = duxai.permission_rules("ask_changes", "~/x", "", "", True)["allow"]
        self.assertFalse(any(r.startswith("Edit(") for r in allow))       # trusted folders only in "trusted"
        self.assertIn(duxai.SCREEN_TOOL, allow)                           # looking at the screen is free
        self.assertNotIn(duxai.SCREEN_TOOL, duxai.permission_rules("ask_all", "", "", "", True)["allow"])

    def test_screen_viewer_flags(self):
        self.run_backend("ask", "--screen", "--", "what's on my screen?")
        self.run_backend("ask", "--", "hi")
        with_screen, without = self.calls()[0]["argv"], self.calls()[1]["argv"]
        self.assertIn("--mcp-config", with_screen)
        self.assertNotIn("--safe-mode", with_screen)        # safe mode would block our tool server
        self.assertIn("mcp__duxai__view_screen", with_screen[with_screen.index("--allowedTools") + 1])
        self.assertNotIn("--mcp-config", without)
        self.assertIn("--safe-mode", without)

    def test_mcp_server_lists_view_screen(self):
        msgs = [{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18"}},
                {"jsonrpc": "2.0", "method": "notifications/initialized"},
                {"jsonrpc": "2.0", "id": 2, "method": "tools/list"}]
        out = subprocess.run([sys.executable, str(BACKEND), "mcp"], input="".join(json.dumps(m) + "\n" for m in msgs),
                             capture_output=True, text=True, env=self.env, timeout=30).stdout
        replies = [json.loads(l) for l in out.splitlines()]
        self.assertEqual([r["id"] for r in replies], [1, 2])
        self.assertEqual(replies[1]["result"]["tools"][0]["name"], "view_screen")

    def test_stop_via_stdin(self):
        """The Windows app stops an answer by writing {"stop": true} (no SIGTERM there)."""
        env = dict(self.env, FAKE_CLAUDE_SLOW="1")
        proc = subprocess.Popen([sys.executable, str(BACKEND), "ask", "--", "hi"], stdin=subprocess.PIPE,
                                stdout=subprocess.PIPE, text=True, env=env)
        events = []
        for line in proc.stdout:
            ev = json.loads(line)
            events.append(ev)
            if ev["type"] == "text":
                proc.stdin.write(json.dumps({"stop": True}) + "\n")
                proc.stdin.flush()
        proc.wait(timeout=30)
        self.assertTrue(events[-1].get("stopped"))
        self.assertTrue(events[-1]["text"].startswith("Hello"))

    def test_target_window_reaches_screen_tool(self):
        self.run_backend("ask", "--screen", "--target-window=4242", "--", "what's this?")
        argv = self.calls()[0]["argv"]
        config = json.loads(argv[argv.index("--mcp-config") + 1])
        self.assertEqual(config["mcpServers"]["duxai"]["env"]["DUXAI_TARGET_WINDOW"], "4242")

    def test_screen_tool_knows_app_pid(self):
        """Windows: the screenshot tool hides the Argos windows of this process id."""
        env = dict(self.env, DUXAI_APP_PID="777")
        self.run_backend("ask", "--screen", "--", "what's this?", env=env)
        argv = self.calls()[0]["argv"]
        config = json.loads(argv[argv.index("--mcp-config") + 1])
        self.assertEqual(config["mcpServers"]["duxai"]["env"]["DUXAI_APP_PID"], "777")

    def test_missing_claude(self):
        env = dict(self.env, PATH="/usr/bin:/bin")
        events = self.run_backend("ask", "--", "hi", env=env)
        self.assertEqual(events[-1]["type"], "error")


if __name__ == "__main__":
    unittest.main()
