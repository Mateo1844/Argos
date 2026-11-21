#!/usr/bin/env bash
# Installs the Argos plugin into DankMaterialShell by symlinking it,
# so a later `git pull` updates the plugin automatically.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dms/plugins"
TARGET="$PLUGIN_DIR/DuxAI"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }

echo "Argos installer"

command -v python3 >/dev/null && ok "python3 found" || { warn "python3 is missing (sudo dnf install python3)"; exit 1; }
command -v dms >/dev/null && ok "dms found" || warn "dms command not found – is DankMaterialShell installed?"
if command -v claude >/dev/null; then
    ok "claude found ($(claude --version 2>/dev/null | head -1))"
else
    warn "Claude Code is not installed: curl -fsSL https://claude.ai/install.sh | bash"
    warn "then run 'claude' once and log in with /login (your Pro subscription)."
fi
python3 -c "import PIL" 2>/dev/null && ok "Pillow found (big screenshots get shrunk)" \
    || warn "optional: sudo dnf install python3-pillow  (shrinks big screenshots = fewer tokens)"

if python3 -c "import ziamath" 2>/dev/null; then
    ok "ziamath found (math formulas are drawn)"
elif python3 -m pip install --user --quiet ziamath 2>/dev/null; then
    ok "installed ziamath (draws math formulas)"
else
    warn "optional: python3 -m pip install --user ziamath  (draws math formulas instead of showing LaTeX code)"
fi

mkdir -p "$PLUGIN_DIR"
if [ -L "$TARGET" ] || [ ! -e "$TARGET" ]; then
    ln -sfn "$REPO_DIR/DuxAI" "$TARGET"
    ok "linked $TARGET -> $REPO_DIR/DuxAI"
else
    warn "$TARGET exists and is not a symlink; remove it and run again"
    exit 1
fi
chmod +x "$REPO_DIR/DuxAI/backend/duxai.py"

if command -v dms >/dev/null; then
    dms ipc call plugins reload duxAi >/dev/null 2>&1 || true
    if dms ipc call plugins enable duxAi 2>/dev/null | grep -q SUCCESS; then
        ok "plugin enabled"
    else
        warn "enable it in DMS Settings → Plugins (click the refresh/scan button first)"
    fi
fi

cat <<'EOF'

Next steps:
  1. DMS Settings → Dank Bar → add the "Argos" widget to your top bar.
  2. Keyboard shortcut: add this inside the binds { } block of ~/.config/niri/config.kdl

     Mod+Shift+A hotkey-overlay-title="Ask Claude about screen" { spawn "dms" "ipc" "call" "widget" "openWith" "duxAi" "capture"; }

     Mod+Shift+X hotkey-overlay-title="Ask Claude about selected text" { spawn "dms" "ipc" "call" "widget" "openWith" "duxAi" "text"; }

     (Mod+A is already the DMS Control Center.)
  3. For selected text: sudo dnf install wl-clipboard
EOF
