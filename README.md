<p align="center">
  <img src="DuxAI/assets/argos.svg" width="96" alt="Argos logo">
</p>

<h1 align="center">Argos</h1>

<p align="center">
  <b>Claude, one click away, on Linux and Windows.</b><br>
  Ask about anything on your screen, let Claude look over your shoulder, and keep it all on your Claude subscription.
</p>

<p align="center">
  <a href="#install-on-linux-dankmaterialshell">Linux (DMS)</a> ·
  <a href="#install-on-windows">Windows</a> ·
  <a href="#using-argos">Using Argos</a> ·
  <a href="#agent-mode">Agent mode</a> ·
  <a href="#settings">Settings</a> ·
  <a href="#how-it-works">How it works</a>
</p>

---

Argos is a small assistant that lives in your **top bar** (DankMaterialShell on Linux) or your
**system tray** (Windows). Click the round Claude button, or press a shortcut, and a chat window opens.
Select part of your screen or some text, and Claude answers with that in view.

It runs on the **Claude Code CLI**, so it uses your Claude **Pro or Max subscription**.
You don't need an API key.

## Features

|   |   |
|---|---|
| 💬 **Chat** | Answers stream in as Markdown. Pick the model (Sonnet, Opus, Haiku) and how hard Claude thinks (low → max). |
| 🖼️ **Ask about your screen** | Draw a box around anything (a slide, a graph, an error) and ask about it. |
| ❝ **Ask about selected text** | Highlight text in any app, press a shortcut, and it's quoted in the chat. |
| 👀 **Screen viewer** | Ask "what does this mean?" without selecting anything: Claude looks at your active window by itself. |
| 🧭 **Knows where you are** | Argos tells Claude which app and window you're in, so "this folder" or "this file" just works. |
| 🫧 **Floating bubble** | A draggable button that stays on top of everything, even fullscreen video, on any monitor. Handy during lectures. |
| 🛠️ **Agent mode** | Claude can read files and run commands for you, and asks before it changes anything. |
| 🗂️ **History** | Continue or delete old chats, and see how much disk space they use. |
| ∑ **Math** | Formulas (LaTeX) are drawn like real LaTeX, inline and as centred blocks. Click a formula to copy its LaTeX. |
| 🪙 **Light on tokens** | A short system prompt, no tools unless needed, and shrunk screenshots. A token counter shows usage. |
| 📊 **Session limit** | The % next to the token counter (e.g. `128 tok · 24%`) is how much of your 5-hour session limit you've used. It turns orange from 80% and red from 95%. |

Both versions share the same chat window, backend and features. Only the way you open them differs.

---

## Install on Linux (DankMaterialShell)

Tested on Fedora with niri and [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell).

```bash
# 1. Claude Code (skip if you have it), then log in once
curl -fsSL https://claude.ai/install.sh | bash
claude                     # type /login, choose your Claude subscription, then /exit

# 2. Argos
git clone https://github.com/Mateo1844/Argos.git ~/Argos
cd ~/Argos && ./install.sh

# 3. Needed for selected text; Pillow (optional) shrinks big screenshots,
#    ziamath draws math formulas (install.sh tries to install it for you)
sudo dnf install wl-clipboard python3-pillow
python3 -m pip install --user ziamath
```

Then:

1. **DMS Settings → Plugins:** enable **Argos**. Press scan/refresh if it isn't listed.
2. **DMS Settings → Dank Bar:** add the **Argos** widget to your bar.
3. **Shortcuts:** add these inside `binds { }` in `~/.config/niri/config.kdl`:

   ```kdl
   Mod+Shift+A hotkey-overlay-title="Ask Claude about screen" { spawn "dms" "ipc" "call" "widget" "openWith" "duxAi" "capture"; }
   Mod+Shift+X hotkey-overlay-title="Ask Claude about selected text" { spawn "dms" "ipc" "call" "widget" "openWith" "duxAi" "text"; }
   ```

   To just open or close the chat, use `spawn "dms" "ipc" "call" "widget" "toggle" "duxAi"`.

<details>
<summary>Other distros (Arch, …)</summary>

Everything works the same, but use your own package manager for `wl-clipboard` and Pillow
(`python-pillow` on Arch). The plugin only needs Python 3, DMS and Claude Code.
</details>

## Install on Windows

Works on Windows 10 (1809 or newer) and Windows 11.

1. Install **Python 3.11+** from [python.org](https://www.python.org/downloads/) and tick
   **"Add python.exe to PATH"**. Python from the Microsoft Store also works.
2. Download Argos with `git clone https://github.com/Mateo1844/Argos.git`, or on GitHub use
   **Code → Download ZIP** and unzip it.
3. Open **PowerShell** in that folder and run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File windows\install.ps1
   ```

   This installs what Argos needs (PySide6, Pillow, and Claude Code if it's missing), adds
   **Argos** to the Start menu, and starts it.
4. Log in to Claude Code once: open a new PowerShell window, run `claude`, type `/login` and
   choose your Claude subscription.
5. Right-click the tray icon → **Settings…** to turn on *Start with Windows*, the floating
   bubble, or to change the shortcuts.

> The tray icon may be hidden under the **^** arrow next to the clock. Drag it onto the
> taskbar to keep it visible.

---

## Using Argos

| | Linux (DMS) | Windows |
|---|---|---|
| **Open the chat** | Click the bar button | Click the tray icon (or set a shortcut in Settings) |
| **Ask about a screen region** | `Mod+Shift+A`, right-click the bar button, or ⛶ in the chat | `Win+Shift+A`, or ⛶ in the chat |
| **Ask about selected text** | `Mod+Shift+X`, or ❝ in the chat | `Win+Shift+X`, or ❝ in the chat |
| **Floating bubble** | Click: the chat opens in the bubble's place; close it with the orange ✕ in its header or Esc. It stays open while you work in other apps. · Right-click: screen region · Drag: move it, also to another monitor | Click: the chat opens in the bubble's place; click anywhere else (or the orange ✕) to close it · Right-click and drag: same as Linux |
| **Settings** | ⚙ in the chat, or DMS Settings → Plugins → Argos | ⚙ in the chat, or tray icon → Settings… |

On Windows, click 📌 in the chat to **pin** it: it then stays open when you click elsewhere.

In the chat, **Enter** sends, **Shift+Enter** adds a new line, and the stop button cancels an
answer. Selecting another region for a follow-up question just works; the old one doesn't come back.

On Windows, "selected text" briefly presses Ctrl+C for you and then puts your clipboard back.

### Screen awareness

- **Active window:** every question quietly includes the app and window title you were using
  (about 20 tokens). For full folder paths, turn this on:
  - **Dolphin:** *Configure Dolphin → Interface → Show the full path inside the title bar*.
  - **File Explorer:** *Folder Options → View → Display the full path in the title bar*.
- **Screen viewer** (on/off with ⚙): when you ask about something you didn't select, Claude can
  take a screenshot of your active window by itself. The chat shows "Looking at your screen…"
  while it does. Argos's own windows are hidden first, so they never block the view.

## Agent mode

Turn on the **Agent** chip next to the model picker. Claude can then read files and run
commands on your computer, using your normal Claude Code setup.

- **It asks before changing anything.** An **Allow / Deny** card shows the exact command or file.
  Every step Claude takes is listed in grey above its answer.
- **Permission level:** *Ask for everything*, *Ask for changes* (default), or *Trusted folders*
  (free edits only inside the folders you list).
- **Folder rules:** *Always ask for these folders* and *Never touch these folders*.
  When rules overlap, *never* beats *ask*, which beats *trusted*.
- **Always blocked**, whatever you click: `sudo`, `rm -rf`, `~/.ssh` and `~/.gnupg`.
- **Cost:** agent mode uses more tokens than the normal chat, because Claude Code's tools and
  instructions are sent along.

> The folder rules cover Claude's file tools. A shell command could still touch any file, so
> every command that changes something asks first and shows the full command. Keep backups of
> important work anyway.

On Windows, agent mode runs commands in bash if Git for Windows is installed, otherwise in PowerShell.

---

## Settings

Open them with ⚙ in the chat (quick switches) or in the full settings
(*DMS Settings → Plugins → Argos* on Linux, *tray icon → Settings…* on Windows).

| Setting | What it does |
|---|---|
| Model / thinking level | Defaults for new chats, plus the list of models in the picker |
| Web search | Lets Claude search the web (off by default, saves tokens) |
| Screen viewer | Claude may look at your active window when needed |
| Include active window | Sends the app and window title with each question |
| Floating bubble | Shows the draggable bubble |
| Agent mode by default | New chats start in agent mode |
| Permission level and folder rules | See [Agent mode](#agent-mode) |
| Screenshot size limit | Larger screenshots are shrunk (fewer tokens) |
| Extra instructions | Added to every chat, for example "Answer in Dutch" |
| Bar icon background | Claude orange, theme/Windows accent colour, or transparent (logo only). On Windows this styles the tray icon and the bubble. |
| Window border | Thin outline around the chat window |
| Show token and session usage | The small `128 tok · 24%` counter in the chat |
| *Windows only:* Start with Windows, shortcuts | Autostart, and the global shortcuts (region, selected text, and an optional one to open the chat). Shortcut changes apply after restarting Argos. |

**Your own logo:** save an SVG as `DuxAI/assets/logo.svg` and it's shown inside the round
button and the bubble. Without it, a sparkle icon is used.

## Updating and uninstalling

| | Linux (DMS) | Windows |
|---|---|---|
| **Update** | `cd ~/Argos && git pull && dms ipc call plugins reload duxAi` | Quit Argos (tray → Quit), run `git pull` in the Argos folder, start Argos again |
| **Uninstall** | Remove `~/.config/dms/plugins/DuxAI` and the Argos folder | Delete `%USERPROFILE%\.duxai-venv`, the Argos folder and the *Argos* Start-menu entry |
| **Chats are stored in** | `~/.local/share/dux-ai` | `%USERPROFILE%\.dux-ai` |

Deleting a chat in the history also deletes its screenshots and Claude Code's own copy of the
conversation.

<details>
<summary>Troubleshooting</summary>

- **Linux: the plugin doesn't show up** → DMS Settings → Plugins → scan/refresh, or run
  `dms ipc call plugin-scan rescan duxAi`.
- **Linux: QML errors** show up in the DMS log output.
- **Windows: nothing happens after installing** → start Argos from the Start menu. Problems are
  written to `%USERPROFILE%\.dux-ai\windows-app.log`.
- **Windows: "shortcut already in use"** → another app uses it. Pick a different one in Settings.
- **Answers fail with a login or authentication error** → run `claude` in a terminal and type `/login`.
- **Old setups:** the repository used to be called *DUX-AI*. Old clones keep working, and the
  plugin id is still `duxAi`.
</details>

---

## How it works

```
  chat window (QML)  ──runs──▶  backend/duxai.py  ──runs──▶  claude -p  (Claude Code CLI)
        ▲                              │
        └──── one JSON line per event ◀┘          chats saved as plain JSON files
```

| Part | What it is |
|---|---|
| `DuxAI/DuxAIWidget.qml` | The whole UI in one file: bar button, chat, history, bubble. Shared by both versions. |
| `DuxAI/DuxAISettings.qml`, `plugin.json` | DMS plugin settings and metadata. |
| `DuxAI/backend/duxai.py` | Plain Python, no required packages. Starts `claude`, streams the answer, saves chats, takes screenshots, and provides the small screen-viewer tool. |
| `DuxAI/backend/winutil.py` | Windows helpers (screenshots, window info, hotkeys) using only `ctypes`. |
| `windows/duxai_windows.pyw` | The Windows tray app (PySide6): tray, shortcuts, region selection, settings window. |
| `windows/shims.py`, `windows/qml/` | Small stand-ins for the DMS/Quickshell parts, so the same QML runs on Windows unchanged. |
| `tests/` | Backend tests, using a fake `claude`. |

Follow-up questions use `claude --resume`, so Claude keeps the context, and prompt caching makes
those resends cheap.

### How it saves tokens

| Measure | Why it helps |
|---|---|
| Own short system prompt | Replaces Claude Code's large coding-agent prompt. This is the biggest saving. |
| No tools unless needed | No tool definitions in every message. Web search and the screen viewer are opt-in. |
| Safe mode in normal chat | Your CLAUDE.md files, MCP servers, plugins and skills aren't loaded. |
| Runs in an empty folder | No project files or git status in the context. |
| Screenshots shrunk (1280 px default) | Image tokens grow with the number of pixels. |
| Titles from your first message | No extra request just to name a chat. |

### Development

```bash
python3 -m unittest discover tests                              # backend tests
python3 DuxAI/backend/duxai.py ask --model=haiku -- "Hello!"    # try the backend alone
dms ipc call plugins reload duxAi                               # reload after editing QML (Linux)
```

After using a new icon name in the QML, run `windows/tools/make_icon_font.py` to update the
small icon font used on Windows.

## Ideas for later

- **Lecture mode:** "explain the last 2 minutes" using local speech-to-text
- Paste images from the clipboard
- Search in history
- Keep one `claude` process alive per chat for faster replies
