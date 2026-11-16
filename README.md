# DUX-AI

Claude in your DankMaterialShell top bar. A small round button opens a chat
window. You pick the model and thinking level, select part of your screen and
ask about it, and browse or delete old chats.

It runs on the **Claude Code CLI**, so it uses your Claude **Pro/Max
subscription**. You don't need an API key.

## Features (v0.1)

- **Bar button:** a round circle in the bar. Left-click opens the chat. Right-click
  starts a screen selection.
- **Chat:** answers stream in token by token and render as Markdown. You can
  select and copy text. Enter sends, Shift+Enter adds a new line, the stop
  button cancels.
- **Model and thinking pickers:** Sonnet, Opus or Haiku, and thinking level
  low → max (Claude Code's `--effort`).
- **Ask about your screen:** the camera-frame button, right-click, or
  **Mod+Shift+A** opens a region selector. After you select, the chat opens
  with the screenshot attached.
- **History page:** open, continue or delete old chats. The bottom of the page
  shows how much disk space saved chats use.

## Install (Fedora + niri + DMS)

```bash
# 1. Claude Code (skip if you already have it), then log in once
curl -fsSL https://claude.ai/install.sh | bash
claude            # type /login, choose your Claude subscription, then /exit

# 2. This plugin
git clone https://github.com/Mateo1844/DUX-AI.git ~/DUX-AI
cd ~/DUX-AI && ./install.sh

# 3. Optional: shrinks big screenshots so they use fewer tokens
sudo dnf install python3-pillow
```

Then:

1. **DMS Settings → Plugins:** enable **DUX-AI** (press scan/refresh if you
   don't see it).
2. **DMS Settings → Dank Bar:** add the **DUX-AI** widget to your bar.
3. **Keyboard shortcut:** add this inside `binds { }` in
   `~/.config/niri/config.kdl`:

   ```kdl
   Mod+Shift+A hotkey-overlay-title="Ask Claude about screen" { spawn "dms" "ipc" "call" "widget" "openWith" "duxAi" "capture"; }
   ```

   `Mod+A` is already the DMS Control Center, so the shortcut uses
   `Mod+Shift+A`. To only open the chat, use
   `spawn "dms" "ipc" "call" "widget" "toggle" "duxAi"`.

To update later: `cd ~/DUX-AI && git pull && dms ipc call plugins reload duxAi`.

## How it works

```
 bar button / popout (QML)  ──runs──▶  backend/duxai.py  ──runs──▶  claude -p (Claude Code CLI)
        ▲                                   │
        └──── one JSON object per line ◀────┘   chats saved in ~/.local/share/dux-ai/
```

- `DuxAI/DuxAIWidget.qml` is the UI only: the bar button, chat, history and
  pickers.
- `DuxAI/backend/duxai.py` is plain Python with no required packages. It
  starts `claude`, streams the answer back, and saves, lists and deletes
  chats. It also takes screenshots, using `dms screenshot region`, or
  `grim` + `slurp` if `dms` isn't available.
- Follow-up messages use `claude --resume <session>`, so Claude keeps the
  conversation context. Prompt caching makes those resends cheap.
- Deleting a chat also deletes its screenshots and Claude Code's own
  transcript in `~/.claude/projects/`.

You can try the backend on its own in a terminal:

```bash
python3 DuxAI/backend/duxai.py ask --model=haiku --effort=low -- "Hello!"
python3 DuxAI/backend/duxai.py list
```

## How it saves tokens

These measures don't hurt answer quality:

| What | Why it helps |
|---|---|
| Own short system prompt (`--system-prompt`) | Replaces Claude Code's large coding-agent prompt. This is the biggest saving. |
| No tools by default (`--tools ""`) | No tool definitions are sent with every message. Web search is an opt-in setting. |
| `--safe-mode`, `--strict-mcp-config`, `--disable-slash-commands` | Your CLAUDE.md files, MCP servers, plugins and skills aren't loaded into the chat. |
| Runs in an empty folder | No project files or git status in the context. |
| Screenshots shrunk to 1280 px | Image tokens grow with pixel count. Needs Pillow. The size is adjustable. |
| Chat titles come from your first message | No extra API call to name a chat. |
| "Be concise" in the system prompt | Shorter answers use fewer output tokens. |

Flags your Claude Code version doesn't support are skipped automatically.

## Settings

In DMS Settings → Plugins → DUX-AI you can set:

- default model and thinking level
- the list of models in the picker
- web search on or off
- screenshot size limit
- extra instructions (for example "Answer in Dutch")
- bar icon color

**Bar icon:** to use a logo (for example the official Claude logo), save it as
`DuxAI/assets/logo.svg`. It shows inside the circle. Without it you get a
sparkle icon.

## Development

```bash
python3 -m unittest discover tests     # backend tests, use a fake `claude`
dms ipc call plugins reload duxAi      # reload after editing QML
# QML errors show up in the DMS shell log output
```

## Roadmap ideas

- Paste images from the clipboard
- Keep one `claude` process alive per chat for faster replies
- Search in history
