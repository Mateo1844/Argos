# DUX-AI

Claude in your Dux Shell top bar. A small round button opens a chat
window. You pick the model and thinking level, select part of your screen and
ask about it, and browse or delete old chats.

It runs on the **Claude Code CLI**, so it uses your Claude **Pro/Max
subscription**. You don't need an API key.

There are two versions, and they share the same chat window and backend:

- **Linux:** a DankMaterialShell bar widget (below).
- **Windows:** a tray app, see [Windows](#windows).

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
- **Ask about selected text:** highlight text anywhere (a PDF, a website, a
  terminal), then press **Mod+Shift+X** or the quote button in the chat. The
  text is attached as a quote. Needs `wl-clipboard`.
- **Token counter:** a small grey number next to the pickers shows how many
  tokens the current chat has used. Hover it to see the last answer's tokens
  (input, how much of it was cached, output).
- **Floating bubble** (setting): a small draggable round button that stays
  on top of everything, including fullscreen video, which is handy during
  lectures. Click opens the chat right next to the bubble, above the video;
  Esc or another click closes it. Right-click asks about a screen region.
- **History page:** open, continue or delete old chats. The bottom of the page
  shows how much disk space saved chats use.

## Agent mode (Claude uses your PC)

Turn on the **Agent** chip next to the pickers. Claude can then read files and
run commands on your computer, using your normal Claude Code setup (your
settings, permissions and MCP servers). Its prompt runs in your home folder.

- **It asks before changing anything.** An *Allow / Deny* card shows the
  exact command or file. Every action Claude takes is listed as a small grey
  step above its answer.
- **Permission level** (Settings): *Ask for everything*, *Ask for changes*
  (default), or *Trusted folders* (free edits only inside folders you list).
- **Folder lists:** *Always ask for these folders* and *Never touch these
  folders*. The order of precedence is deny > ask > allow.
- **Always blocked:** `sudo`, `rm -rf`, `~/.ssh` and `~/.gnupg`, whatever you
  click.
- **Seeing your screen:** with the screen viewer on, the agent can look at
  your screen without asking (except at the *Ask for everything* level).
- **Cost:** it uses more tokens than the normal chat, because Claude Code's
  tools and instructions are sent along. Normal chat stays lean.

The folder rules cover Claude's file tools. A shell command could still touch
a file, so every command that changes something asks first and shows the full
command. Keep backups of important work anyway.

## Active window and screen viewer

- **Active window:** DUX-AI quietly sends along which app and window title you
  were looking at (about 20 tokens). That's how "rename the files in this
  folder" or "explain this file" works. In Dolphin, turn on *Configure Dolphin →
  Interface → Show the full path inside the title bar* to send the full path.
- **Screen viewer:** when you ask about something on screen that you didn't
  select, Claude can take a screenshot of your active window by itself and
  look at it. This works in normal chat and in agent mode. It happens through
  a small built-in tool, so no command or Allow/Deny card shows up. The
  chat only says "Looking at your screen…" while it happens.
- **Gear button in the chat:** quick switches for *Web search* and *Screen
  viewer*. The same options are in the plugin settings.

## Install (Fedora + niri + DMS)

```bash
# 1. Claude Code (skip if you already have it), then log in once
curl -fsSL https://claude.ai/install.sh | bash
claude            # type /login, choose your Claude subscription, then /exit

# 2. This plugin
git clone https://github.com/Mateo1844/DUX-AI.git ~/DUX-AI
cd ~/DUX-AI && ./install.sh

# 3. wl-clipboard for selected text; Pillow (optional) shrinks big screenshots
sudo dnf install wl-clipboard python3-pillow
```

Then:

1. **DMS Settings → Plugins:** enable **DUX-AI** (press scan/refresh if you
   don't see it).
2. **DMS Settings → Dank Bar:** add the **DUX-AI** widget to your bar.
3. **Keyboard shortcut:** add this inside `binds { }` in
   `~/.config/niri/config.kdl`:

   ```kdl
   Mod+Shift+A hotkey-overlay-title="Ask Claude about screen" { spawn "dms" "ipc" "call" "widget" "openWith" "duxAi" "capture"; }
   Mod+Shift+X hotkey-overlay-title="Ask Claude about selected text" { spawn "dms" "ipc" "call" "widget" "openWith" "duxAi" "text"; }
   ```

   `Mod+A` is already the DMS Control Center, so the shortcut uses
   `Mod+Shift+A`. To only open the chat, use
   `spawn "dms" "ipc" "call" "widget" "toggle" "duxAi"`.

To update later: `cd ~/DUX-AI && git pull && dms ipc call plugins reload duxAi`.

## Windows

The Windows version is a tray app with the same chat window, history, agent
mode, screen viewer and settings.

| | Linux (DMS) | Windows |
|---|---|---|
| Open the chat | Bar button | Tray icon next to the clock, or the floating bubble |
| Ask about a screen region | Mod+Shift+A | **Win+Shift+A** |
| Ask about selected text | Mod+Shift+X | **Win+Shift+X** (it quickly presses Ctrl+C for you, then puts your clipboard back) |
| Settings | DMS Settings → Plugins | Right-click the tray icon → Settings… |
| Chats are stored in | `~/.local/share/dux-ai` | `%LOCALAPPDATA%\dux-ai` |

**Install** (Windows 10 1809+ or 11):

1. Install **Python 3.11+** from [python.org](https://www.python.org/downloads/)
   and tick *"Add python.exe to PATH"*.
2. Get the code: `git clone https://github.com/Mateo1844/DUX-AI.git`, or on
   GitHub use *Code → Download ZIP* and unzip it.
3. In PowerShell, in the DUX-AI folder, run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File windows\install.ps1
   ```
   This installs PySide6 (the core part) and Pillow, installs Claude Code if it's missing,
   adds DUX-AI to the Start menu and starts it.
4. Log in to Claude Code once: open a new PowerShell window, run `claude`,
   type `/login` and choose your Claude subscription.
5. Right-click the tray icon → *Settings…* to turn on *Start with Windows*,
   the floating bubble, or to change the shortcuts.

**Notes:**
- **Use Python from python.org, not the Microsoft Store.** The Store version
  installs packages in such a deep folder that PySide6 fails with a "Long
  Path" error. If you want to keep the Store version, allow long paths first
  (PowerShell *as administrator*):
  `New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force`
- The tray icon may be hidden under the **^** arrow next to the clock. Drag it
  onto the taskbar to keep it visible.
- To show the full folder path in File Explorer's title (for "this folder"),
  open *Folder Options → View* and tick *"Display the full path in the title
  bar"*.
- Git for Windows is optional. With it, agent mode runs commands in bash;
  without it, in PowerShell.
- Problems are written to `%LOCALAPPDATA%\dux-ai\windows-app.log`.

## How it works

```
 bar button / popout (QML)  ──runs──▶  backend/duxai.py  ──runs──▶  claude -p (Claude Code CLI)
        ▲                                   │
        └──── one JSON object per line ◀────┘   chats saved in ~/.local/share/dux-ai/
```

- `DuxAI/DuxAIWidget.qml` is the UI only (one file, so `plugins reload` always picks up changes): the bar button, chat, history and
  pickers. The Windows app loads this same file.
- `windows/` is the Windows app. `duxai_windows.pyw` handles the tray,
  shortcuts, region selection and selected text. `shims.py` and `qml/` are
  small stand-ins for the DMS/Quickshell parts the chat window uses, so the
  QML runs unchanged. `fonts/DuxIcons.ttf` is a 10 KB copy of the icon font;
  run `windows/tools/make_icon_font.py` after using a new icon name.
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
- bar icon background: Claude orange, theme color, or transparent (logo only)
- window border on/off

**Bar icon:** to use a logo (for example the official Claude logo), save it as
`DuxAI/assets/logo.svg`. It is shown in white inside the circle, in the bar
and in the chat window. Without it you get a sparkle icon.

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
