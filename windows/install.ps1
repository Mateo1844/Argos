# DUX-AI for Windows: one-time setup.
#
# In PowerShell, from the DUX-AI folder:
#     powershell -ExecutionPolicy Bypass -File windows\install.ps1
#
# It installs the Python packages, Claude Code (if missing), adds DUX-AI to
# the Start menu and starts it. Nothing here needs administrator rights.

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$app = Join-Path $here "duxai_windows.pyw"

function Ok($text)   { Write-Host "  [ok] $text" -ForegroundColor Green }
function Warn($text) { Write-Host "  [!]  $text" -ForegroundColor Yellow }

Write-Host "DUX-AI installer"

# 1. Python (from python.org or the Microsoft Store)
$python = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $python -or $python -like "*WindowsApps\python.exe") {
    $py = (Get-Command py -ErrorAction SilentlyContinue).Source
    if ($py) { $python = (& $py -3 -c "import sys; print(sys.executable)").Trim() }
}
if (-not $python) {
    Warn "Python not found. Install Python 3.11+ from https://www.python.org (tick 'Add python.exe to PATH'), then run this again."
    exit 1
}
Ok "Python: $python"
$pythonw = Join-Path (Split-Path $python) "pythonw.exe"
if (-not (Test-Path $pythonw)) { $pythonw = $python }

# 2. Python packages (PySide6 = the window toolkit, Pillow = screenshots)
& $python -m pip install --user --upgrade --quiet -r (Join-Path $here "requirements.txt")
Ok "Python packages installed"

# 3. Claude Code
$claude = Join-Path $env:USERPROFILE ".local\bin\claude.exe"
if ((Test-Path $claude) -or (Get-Command claude -ErrorAction SilentlyContinue)) {
    Ok "Claude Code found"
} else {
    Write-Host "  Installing Claude Code (no progress bar, takes a minute)..."
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    Ok "Claude Code installed"
}

# 4. Start menu shortcut (search "DUX-AI" in Start to launch it)
$startMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\DUX-AI.lnk"
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($startMenu)
$link.TargetPath = $pythonw
$link.Arguments = "`"$app`""
$link.WorkingDirectory = Split-Path $here
$link.Description = "Claude in your tray"
$link.Save()
Ok "Start menu shortcut created"

# 5. Start it
Start-Process -FilePath $pythonw -ArgumentList "`"$app`""
Ok "DUX-AI started: look for the orange icon next to the clock (maybe under the ^ arrow)"

Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Log in to Claude Code once: open a NEW PowerShell window, type  claude  and use /login"
Write-Host "     (choose your Claude subscription), then /exit."
Write-Host "  2. Tray icon -> right-click -> Settings: 'Start with Windows', floating bubble, shortcuts."
Write-Host "  3. Shortcuts: Win+Shift+A = ask about a screen region, Win+Shift+X = ask about selected text."
Write-Host "  Optional: Git for Windows (git-scm.com) lets agent mode use bash instead of PowerShell."
