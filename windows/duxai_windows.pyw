"""Argos for Windows: Claude in your system tray.

Start it with:  pythonw windows\\duxai_windows.pyw   (or run install.ps1 once)

What this file does:
  * loads the SAME chat window as the DMS version (DuxAI/DuxAIWidget.qml),
    with stand-ins for the DMS/Quickshell parts (windows/qml + shims.py)
  * tray icon (click = chat), optional floating bubble (a setting)
  * global shortcuts: Win+Shift+A (screen region), Win+Shift+X (selected text)
  * region selection overlay and "selected text" via a quick Ctrl+C
  * keeps track of the window you were last in (for "this file/page")

Everything else (talking to Claude, chats, tokens) is the shared backend:
DuxAI/backend/duxai.py.
"""

import json
import os
import sys
import threading
import time
import traceback
from pathlib import Path


def startup_error(text):
    """pythonw has no console: show problems at start-up in a message box."""
    if os.name == "nt":
        import ctypes
        ctypes.windll.user32.MessageBoxW(None, text, "Argos could not start", 0x10)
    print(text, file=sys.stderr)
    raise SystemExit(1)


try:
    import PySide6  # noqa: F401
except ImportError:
    startup_error("PySide6 is not installed for this Python:\n" + sys.executable +
                  "\n\nRun windows\\install.ps1 again and check its output, or start Argos from the "
                  "Start menu entry the installer made.")


def help_windows_find_qt_dlls():
    """Windows: let Qt's plugins (dark style, layouts, ...) find PySide6's DLLs.

    Qt loads those plugins from subfolders; Windows then looks for the DLLs
    they need in the wrong places ("The specified module could not be found"),
    especially with Python from the Microsoft Store. So: add PySide6's folder
    to the search path and load the Qt Quick DLLs in advance.
    """
    import ctypes
    import PySide6
    qt_dir = Path(PySide6.__file__).resolve().parent
    os.add_dll_directory(str(qt_dir))
    os.environ["PATH"] = str(qt_dir) + os.pathsep + os.environ.get("PATH", "")
    for pattern in ("Qt6Qml*.dll", "Qt6Quick*.dll", "Qt6Svg*.dll", "Qt6OpenGL.dll"):
        for dll in sorted(qt_dir.glob(pattern)):
            try:
                ctypes.WinDLL(str(dll))
            except OSError:
                pass   # not needed by Argos, or loads later anyway


if os.name == "nt":
    help_windows_find_qt_dlls()

from PySide6.QtCore import Q_ARG, QMetaObject, QObject, QPoint, QRect, Qt, QTimer, QUrl, Property, Signal, Slot, QMimeData
from PySide6.QtGui import QAction, QColor, QFont, QFontDatabase, QGuiApplication, QIcon, QPainter, QPen, QPixmap
from PySide6.QtQml import QJSValue, QQmlComponent, QQmlEngine, qmlRegisterType
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon, QWidget

HERE = Path(__file__).resolve().parent            # .../<repo folder>/windows
PLUGIN = HERE.parent / "DuxAI"                    # the DMS plugin folder (shared QML + backend)
BACKEND = PLUGIN / "backend" / "duxai.py"
sys.path.insert(0, str(BACKEND.parent))
sys.path.insert(0, str(HERE))

import duxai  # noqa: E402  (shared backend: data folder, chat files)
import shims  # noqa: E402  (registers the Quickshell stand-ins)

IS_WINDOWS = os.name == "nt"
if IS_WINDOWS:
    import winutil  # noqa: E402

SETTINGS_FILE = duxai.DATA_DIR / "settings.json"
LOG_FILE = duxai.DATA_DIR / "windows-app.log"
ACCENT = "#D97757"
DEFAULT_HOTKEYS = {"hotkeyCapture": "Win+Shift+A", "hotkeyText": "Win+Shift+X", "hotkeyChat": ""}


def log(*parts):
    """pythonw has no console: errors go to a log file next to the chats."""
    try:
        duxai.DATA_DIR.mkdir(parents=True, exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + " ".join(str(p) for p in parts) + "\n")
    except OSError:
        pass


# =================================================================== bridge ==

class Bridge(QObject):
    """The `dux` object the QML stand-ins talk to: settings, commands,
    notifications, icons, the active window."""

    settingsChanged = Signal()
    action = Signal(str, arguments=["name"])   # "toggle", "chat", "capture", "text" -> chat window
    startWithWindowsChanged = Signal()
    holdPopupChanged = Signal()
    trayStateChanged = Signal(str)   # "busy", "done" or "" (see tray in build())

    def __init__(self, app):
        super().__init__()
        self.app = app
        self.tray = None
        self.toast = None
        self._app_icon_url = ""
        self.last_hwnd = 0               # last window you used that isn't Argos
        self.last_window = {"app": "", "title": ""}
        self._hold = False
        self._procs = {}
        self._icons = json.loads((HERE / "fonts" / "icons.json").read_text())
        font_id = QFontDatabase.addApplicationFont(str(HERE / "fonts" / "DuxIcons.ttf"))
        families = QFontDatabase.applicationFontFamilies(font_id) if font_id >= 0 else []
        self._icon_font = families[0] if families else ""
        try:
            self._settings = json.loads(SETTINGS_FILE.read_text())
        except (OSError, ValueError):
            self._settings = {}

    # --- settings (what DMS calls pluginData) ---
    def _get_settings(self):
        return self._settings

    settings = Property("QVariantMap", _get_settings, notify=settingsChanged)

    def setting(self, key, default=None):
        value = self._settings.get(key)
        return default if value is None else value

    @Slot(str, "QVariant")
    def saveSetting(self, key, value):
        self._settings = {**self._settings, key: value}
        duxai.DATA_DIR.mkdir(parents=True, exist_ok=True)
        SETTINGS_FILE.write_text(json.dumps(self._settings, indent=1))
        self.settingsChanged.emit()

    # --- icons and fonts ---
    @Slot(str, result=str)
    def icon(self, name):
        code = self._icons.get(name)
        return chr(code) if code else ""

    iconFont = Property(str, lambda self: self._icon_font, constant=True)

    def _system_accent(self):
        """Windows' accent colour (Settings > Personalisation > Colours)."""
        try:
            from PySide6.QtGui import QPalette
            colour = QGuiApplication.palette().color(QPalette.Accent)
            if colour.isValid() and colour.alpha() > 0:
                return colour.name()
        except Exception:  # noqa: BLE001 - older Qt
            pass
        return ACCENT

    systemAccent = Property(str, _system_accent, constant=True)
    textFont = Property(str, lambda self: "Segoe UI" if IS_WINDOWS else "", constant=True)

    # --- popup helpers ---
    def _get_hold(self):
        return self._hold

    holdPopup = Property(bool, _get_hold, notify=holdPopupChanged)

    @Slot(result=QRect)
    def primaryWorkArea(self):
        """Usable area (without taskbar) of the main screen."""
        return QGuiApplication.primaryScreen().availableGeometry()

    @Slot(int, int, result=QRect)
    def workAreaAt(self, x, y):
        """Usable area of the screen that contains this point."""
        screen = QGuiApplication.screenAt(QPoint(x, y)) or QGuiApplication.primaryScreen()
        return screen.availableGeometry()

    @Slot(str, result=QRect)
    def workAreaOf(self, screen_name):
        """Usable area (without taskbar) of the screen with this name (or the main screen)."""
        for screen in QGuiApplication.screens():
            if screen.name() == screen_name:
                return screen.availableGeometry()
        return QGuiApplication.primaryScreen().availableGeometry()

    @Slot(result=QRect)
    def workArea(self):
        """Usable area (without taskbar) of the screen the mouse is on."""
        screen = QGuiApplication.screenAt(QCursorPos()) or QGuiApplication.primaryScreen()
        return screen.availableGeometry()

    @Slot(QObject)
    def forceForeground(self, window):
        if IS_WINDOWS:
            try:
                winutil.set_foreground(int(window.winId()))
            except Exception:  # noqa: BLE001 - best effort only
                pass

    @Slot(str, str, bool)
    def notify(self, message, details, error):
        self.show_toast(message, details, error)

    def show_toast(self, heading, message="", error=False, action_label="", action_key=""):
        """Argos's own notification card (Windows' own would say it's from "Python")."""
        if self.toast is not None:
            QMetaObject.invokeMethod(self.toast, "showToast", Q_ARG("QVariant", heading), Q_ARG("QVariant", message),
                                     Q_ARG("QVariant", bool(error)), Q_ARG("QVariant", action_label),
                                     Q_ARG("QVariant", action_key))

    appIconUrl = Property(str, lambda self: self._app_icon_url, constant=True)
    # The Argos logo (the dog), shown inside the app: settings header, notifications.
    argosLogoUrl = Property(str, lambda self: QUrl.fromLocalFile(str(PLUGIN / "assets" / "argos.svg")).toString(),
                            constant=True)

    # --- start with Windows: a shortcut in your Startup folder ---
    # Made through PowerShell: Python from the Microsoft Store would secretly
    # redirect its own writes (registry and AppData) where Windows doesn't look.
    @staticmethod
    def _startup_link():
        return Path(os.environ.get("APPDATA", "")) / "Microsoft/Windows/Start Menu/Programs/Startup/Argos.lnk"

    @staticmethod
    def _old_startup_link():   # from when Argos was called DUX-AI
        return Path(os.environ.get("APPDATA", "")) / "Microsoft/Windows/Start Menu/Programs/Startup/DUX-AI.lnk"

    def _get_autostart(self):
        return IS_WINDOWS and (self._startup_link().exists() or self._old_startup_link().exists())

    startWithWindows = Property(bool, _get_autostart, notify=startWithWindowsChanged)

    @Slot(bool)
    def setStartWithWindows(self, on):
        if not IS_WINDOWS:
            return
        import subprocess
        link = str(self._startup_link()).replace("'", "''")
        old = str(self._old_startup_link()).replace("'", "''")
        if on:
            pythonw = Path(sys.executable).with_name("pythonw.exe")
            target = str(pythonw if pythonw.exists() else sys.executable).replace("'", "''")
            app = str(Path(__file__).resolve()).replace("'", "''")
            ico = str(duxai.DATA_DIR / "duxai.ico").replace("'", "''")
            script = (f"$l = (New-Object -ComObject WScript.Shell).CreateShortcut('{link}'); "
                      f"$l.TargetPath = '{target}'; $l.Arguments = '\"{app}\"'; "
                      f"if (Test-Path '{ico}') {{ $l.IconLocation = '{ico}' }}; $l.Save()")
        else:
            script = f"Remove-Item -LiteralPath '{link}' -ErrorAction SilentlyContinue"
        script += f"; Remove-Item -LiteralPath '{old}' -ErrorAction SilentlyContinue"
        subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", script],
                       creationflags=0x08000000, timeout=20)   # CREATE_NO_WINDOW
        self.startWithWindowsChanged.emit()

    @Slot(str)
    def setTrayState(self, state):
        self.trayStateChanged.emit(state)

    # --- commands from the chat window (DMS's Proc.runCommand) ---
    @Slot(str, "QVariantList", "QJSValue")
    def runCommand(self, cid, command, callback):
        cmd = shims.python_command(command)
        op = cmd[2] if len(cmd) > 2 and cmd[1].endswith("duxai.py") else ""

        def reply(out, code=0):
            if isinstance(callback, QJSValue) and callback.isCallable():
                callback.call([QJSValue(out), QJSValue(code)])

        # These three are done here instead of in the backend (Linux tools there).
        if op == "capture":
            self.capture_region(lambda path: reply(json.dumps(
                {"type": "captured", "path": path} if path else {"type": "cancelled"})))
            return
        if op == "selection":
            self.grab_selection(lambda text: reply(json.dumps(
                {"type": "selection", "text": text} if text else
                {"type": "error", "message": "No selected text found. Highlight some text first."})))
            return
        if op == "window":
            reply(json.dumps({"type": "window", **self.last_window}))
            return

        from PySide6.QtCore import QProcess
        proc = QProcess(self)
        key = f"{cid}-{id(proc)}"
        self._procs[key] = proc

        def finished(code, _status):
            out = bytes(proc.readAllStandardOutput()).decode("utf-8", "replace")
            self._procs.pop(key, None)
            reply(out, code)
            proc.deleteLater()

        proc.finished.connect(finished)
        proc.start(cmd[0], cmd[1:])

    # --- active window tracking ---
    def track_window(self):
        if not IS_WINDOWS:
            return
        hwnd = winutil.foreground_window()
        info = winutil.window_info(hwnd)
        if not hwnd or info["pid"] == os.getpid() or not info["title"]:
            return   # Argos itself, the desktop, or the taskbar: keep the previous window
        if hwnd != self.last_hwnd or info["title"] != self.last_window["title"]:
            self.last_hwnd = hwnd
            self.last_window = {"app": info["app"], "title": info["title"]}
            if shims.ToplevelManager._instance:
                shims.ToplevelManager._instance.set_active(info["app"], info["title"])

    # --- region screenshot: dim the screen, drag a rectangle ---
    def capture_region(self, done):
        overlays = []

        def finish(path):
            for o in overlays:
                o.close()
            done(path)
            # The full-screen selection covered everything: put the bubble back on top.
            QTimer.singleShot(150, lambda: getattr(self, "reassertOnTop", lambda: None)())

        for screen in QGuiApplication.screens():
            overlays.append(RegionOverlay(screen, finish))
        for o in overlays:
            o.showFullScreen()
            o.raise_()
            o.activateWindow()
        if overlays:
            under_mouse = next((o for o in overlays if o.geometry().contains(QCursorPos())), overlays[0])
            under_mouse.activateWindow()
            if IS_WINDOWS:
                winutil.set_foreground(int(under_mouse.winId()))

    # --- selected text: press Ctrl+C in your window, read, restore clipboard ---
    def grab_selection(self, done):
        clipboard = QGuiApplication.clipboard()
        saved = QMimeData()
        old = clipboard.mimeData()
        for fmt in old.formats() if old else []:
            saved.setData(fmt, old.data(fmt))
        clipboard.clear()
        target = self.last_hwnd

        def press_copy():
            if IS_WINDOWS:
                winutil.set_foreground(target)   # in case the chat or tray menu was in front
                time.sleep(0.12)
                winutil.copy_selection_keys()

        def wait_for_text(started):
            text = clipboard.text()
            if text or time.time() - started > 0.8:
                clipboard.setMimeData(saved)      # put your old clipboard back
                done(text.strip())
            else:
                QTimer.singleShot(40, lambda: wait_for_text(started))

        thread = threading.Thread(target=press_copy, daemon=True)
        thread.start()
        QTimer.singleShot(60, lambda: wait_for_text(time.time()))


def QCursorPos():  # noqa: N802 - small helper, reads like the Qt call it wraps
    from PySide6.QtGui import QCursor
    return QCursor.pos()


# ======================================================== region overlay ==

class RegionOverlay(QWidget):
    """Full-screen picture of one monitor, darkened; drag to select. Esc cancels."""

    def __init__(self, screen, done):
        super().__init__(None, Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.done = done
        self.shot = screen.grabWindow(0)        # picture of this monitor (real pixels)
        self.setGeometry(screen.geometry())
        self.setCursor(Qt.CrossCursor)
        self.setAttribute(Qt.WA_DeleteOnClose)
        self.start = self.end = None

    def paintEvent(self, _event):
        p = QPainter(self)
        p.drawPixmap(self.rect(), self.shot)
        p.fillRect(self.rect(), QColor(0, 0, 0, 110))
        if self.start and self.end:
            sel = QRect(self.start, self.end).normalized()
            ratio = self.shot.devicePixelRatio() or 1
            src = QRect(int(sel.x() * ratio), int(sel.y() * ratio), int(sel.width() * ratio),
                        int(sel.height() * ratio))
            p.drawPixmap(sel, self.shot, src)
            p.setPen(QPen(QColor(ACCENT), 2))
            p.drawRect(sel.adjusted(0, 0, -1, -1))

    def mousePressEvent(self, event):
        if event.button() == Qt.RightButton:
            self.done("")
            return
        self.start = self.end = event.position().toPoint()
        self.update()

    def mouseMoveEvent(self, event):
        if self.start:
            self.end = event.position().toPoint()
            self.update()

    def mouseReleaseEvent(self, event):
        if not self.start:
            return
        sel = QRect(self.start, event.position().toPoint()).normalized()
        if sel.width() < 5 or sel.height() < 5:
            self.start = self.end = None
            self.update()
            return
        ratio = self.shot.devicePixelRatio() or 1
        crop = self.shot.copy(QRect(int(sel.x() * ratio), int(sel.y() * ratio),
                                    int(sel.width() * ratio), int(sel.height() * ratio)))
        duxai.IMAGES_DIR.mkdir(parents=True, exist_ok=True)
        path = duxai.IMAGES_DIR / time.strftime("shot-%Y%m%d-%H%M%S.png")
        crop.save(str(path), "PNG")
        self.done(str(path))

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            self.done("")


# ================================================================= tray ==

def icon_style(bridge):
    """The "Bar icon background" setting: (circle colour or None, logo colour)."""
    choice = bridge.setting("pillColor", "claude")
    if choice == "transparent":
        return None, QColor(ACCENT)          # just the logo, in Claude orange
    if choice == "theme":
        return QColor(bridge.systemAccent), QColor(Qt.white)
    return QColor(ACCENT), QColor(Qt.white)


def app_pixmap(bridge, size, badge=None):
    """The icon for the tray, taskbar and Start menu: orange circle with the
    Claude logo (DuxAI/assets/logo.svg, made white) or a sparkle. Follows the
    "Bar icon background" setting. (The Argos dog is used for settings.)"""
    circle, ink = icon_style(bridge)
    pix = QPixmap(size, size)
    pix.fill(Qt.transparent)
    p = QPainter(pix)
    p.setRenderHint(QPainter.Antialiasing)
    p.setPen(Qt.NoPen)
    if circle is not None:
        p.setBrush(circle)
        p.drawEllipse(0, 0, size, size)
    logo = PLUGIN / "assets" / "logo.svg"
    pad = round(size * (0.22 if circle is not None else 0.04))
    if logo.exists():
        from PySide6.QtSvg import QSvgRenderer
        glyph = QPixmap(size, size)
        glyph.fill(Qt.transparent)
        gp = QPainter(glyph)
        gp.setRenderHint(QPainter.Antialiasing)
        QSvgRenderer(str(logo)).render(gp, QRect(pad, pad, size - 2 * pad, size - 2 * pad).toRectF())
        gp.setCompositionMode(QPainter.CompositionMode_SourceIn)   # paint it one colour
        gp.fillRect(glyph.rect(), ink)
        gp.end()
        p.drawPixmap(0, 0, glyph)
    else:
        font = QFont(bridge.iconFont)
        font.setPixelSize(round(size * 0.62))
        p.setFont(font)
        p.setPen(ink)
        p.drawText(pix.rect(), Qt.AlignCenter, bridge.icon("auto_awesome"))
    if badge is not None:
        # Status dot in the bottom-right corner, with a dark ring so it shows
        # on any taskbar colour.
        d = round(size * 0.46)
        ring = max(1, round(size * 0.07))
        p.setBrush(QColor("#1F1E1D"))
        p.drawEllipse(size - d, size - d, d, d)
        p.setBrush(badge)
        p.drawEllipse(size - d + ring, size - d + ring, d - 2 * ring, d - 2 * ring)
    p.end()
    return pix


def app_icon(bridge, badge=None):
    icon = QIcon()
    for size in (16, 20, 24, 32, 40, 48, 64, 128, 256):
        icon.addPixmap(app_pixmap(bridge, size, badge))
    return icon


def argos_icon():
    """The Argos dog (DuxAI/assets/argos.svg) as a window icon, in all sizes."""
    from PySide6.QtSvg import QSvgRenderer
    renderer = QSvgRenderer(str(PLUGIN / "assets" / "argos.svg"))
    icon = QIcon()
    for size in (16, 20, 24, 32, 40, 48, 64, 128, 256):
        pix = QPixmap(size, size)
        pix.fill(Qt.transparent)
        p = QPainter(pix)
        p.setRenderHint(QPainter.Antialiasing)
        renderer.render(p, QRect(0, 0, size, size).toRectF())
        p.end()
        icon.addPixmap(pix)
    return icon


def write_icon_files(bridge):
    """icon.png (for notifications) and duxai.ico (for the Start menu shortcut)."""
    duxai.DATA_DIR.mkdir(parents=True, exist_ok=True)
    png = duxai.DATA_DIR / "icon.png"
    app_pixmap(bridge, 256).save(str(png), "PNG")
    try:
        from PIL import Image
        Image.open(png).save(duxai.DATA_DIR / "duxai.ico",
                             sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    except Exception as exc:  # noqa: BLE001 - icon is cosmetic
        log("Could not write duxai.ico:", exc)
    bridge._app_icon_url = QUrl.fromLocalFile(str(png)).toString()
    # The dog, for the settings window's taskbar button.
    try:
        from PIL import Image
        dog = duxai.DATA_DIR / "argos.png"
        argos_icon().pixmap(256, 256).save(str(dog), "PNG")
        Image.open(dog).save(duxai.DATA_DIR / "argos.ico",
                             sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    except Exception as exc:  # noqa: BLE001 - icon is cosmetic
        log("Could not write argos.ico:", exc)


# ================================================================== main ==

def build():
    """Create the app, chat window, tray and shortcuts. Returns (app, bridge, engine, widget)."""
    os.environ.setdefault("QT_QUICK_CONTROLS_MATERIAL_THEME", "Dark")
    os.environ.setdefault("QT_QUICK_CONTROLS_MATERIAL_ACCENT", ACCENT)
    # Dark "Material" look; "Basic" (Qt's plain built-in style) is the fallback.
    QQuickStyle.setStyle(os.environ.get("DUXAI_STYLE", "Material"))
    os.environ["DUXAI_APP_PID"] = str(os.getpid())   # screenshots hide Argos' own windows
    if IS_WINDOWS:
        # Own identity for the taskbar (otherwise windows are grouped under "Python").
        import ctypes
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("Mateo1844.Argos")
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)    # it lives in the tray
    app.setApplicationName("Argos")

    bridge = Bridge(app)
    shims.BRIDGE = bridge
    icon = app_icon(bridge)
    app.setWindowIcon(icon)                 # settings window, taskbar, Alt+Tab
    write_icon_files(bridge)

    engine = QQmlEngine()
    engine.addImportPath(str(HERE / "qml"))
    engine.rootContext().setContextProperty("dux", bridge)
    qmlRegisterType(QUrl.fromLocalFile(str(HERE / "qml" / "PanelWindow.qml")), "Quickshell", 1, 0, "PanelWindow")
    qmlRegisterType(QUrl.fromLocalFile(str(HERE / "qml" / "Region.qml")), "Quickshell", 1, 0, "Region")
    shims.ToplevelManager()   # create the singleton before QML asks for it

    # The chat (same file as on DMS).
    component = QQmlComponent(engine, QUrl.fromLocalFile(str(PLUGIN / "DuxAIWidget.qml")))
    widget = component.create()
    if widget is not None:
        engine.setObjectOwnership(widget, QQmlEngine.CppOwnership)   # don't let QML garbage-collect it
    if widget is None:
        errors = "\n".join(e.toString() for e in component.errors())
        log("Could not load the chat window:\n" + errors)
        if "Cannot load library" in errors and "DUXAI_STYLE" not in os.environ:
            # A style plugin wouldn't load: start again once with the plain style.
            import subprocess
            log("Restarting with the Basic style")
            subprocess.Popen([sys.executable, str(Path(__file__).resolve())], env={**os.environ, "DUXAI_STYLE": "Basic"})
            raise SystemExit(0)
        raise SystemExit("Could not load the chat window:\n" + errors)

    # Tray icon + menu.
    tray = QSystemTrayIcon(icon, app)
    tray.setToolTip("Argos (Claude)")
    bridge.tray = tray

    # Keep the bubble (and other "on top" windows) on top. Windows can lose
    # that silently; re-applying it is cheap, so do it every 2 seconds.
    if IS_WINDOWS:
        def reassert_on_top():
            wins = [w for w in QGuiApplication.topLevelWindows()
                    if w.isVisible() and w.flags() & Qt.WindowStaysOnTopHint]
            wins.sort(key=lambda w: w.width() * w.height(), reverse=True)   # smallest (the bubble) last = highest
            try:
                winutil.keep_on_top([int(w.winId()) for w in wins])
            except Exception as exc:  # noqa: BLE001 - cosmetic
                log("keep_on_top failed:", exc)
        on_top_timer = QTimer(app)
        on_top_timer.timeout.connect(reassert_on_top)
        on_top_timer.start(2000)
        bridge.reassertOnTop = reassert_on_top

    # The "Bar icon background" setting changes the tray icon (and app icon) live.
    last_style = [bridge.setting("pillColor", "claude")]

    # Status dot on the tray icon: blinking amber while Claude works, green when
    # an answer came in while the chat was closed (until you open it).
    tray_state = {"state": "", "blink": False}
    busy_colour, done_colour = QColor("#F2B84B"), QColor("#5FC36B")
    tray_icons = {}

    def tray_icon_for(key):
        if key not in tray_icons:
            badge = {"busy": busy_colour, "done": done_colour}.get(key)
            tray_icons[key] = app_icon(bridge, badge)
        return tray_icons[key]

    def update_tray():
        state = tray_state["state"]
        key = "" if state == "busy" and tray_state["blink"] else state
        tray.setIcon(tray_icon_for(key))
        tray.setToolTip({"busy": "Argos: Claude is working…",
                         "done": "Argos: answer ready"}.get(state, "Argos (Claude)"))
    blink_timer = QTimer(app)
    blink_timer.setInterval(600)

    def blink():
        tray_state["blink"] = not tray_state["blink"]
        update_tray()
    blink_timer.timeout.connect(blink)

    def set_tray_state(state):
        tray_state["state"], tray_state["blink"] = state, False
        if state == "busy":
            blink_timer.start()
        else:
            blink_timer.stop()
        update_tray()
    bridge.trayStateChanged.connect(set_tray_state)

    def restyle_icon():
        if bridge.setting("pillColor", "claude") == last_style[0]:
            return
        last_style[0] = bridge.setting("pillColor", "claude")
        tray_icons.clear()
        new_icon = app_icon(bridge)
        app.setWindowIcon(new_icon)
        update_tray()
    bridge.settingsChanged.connect(restyle_icon)
    menu = QMenu()
    menu.addAction("Open chat", lambda: bridge.action.emit("chat"))
    menu.addAction("Ask about a screen region", lambda: bridge.action.emit("capture"))
    menu.addAction("Ask about selected text", lambda: bridge.action.emit("text"))
    menu.addSeparator()
    bubble_action = QAction("Floating bubble", menu, checkable=True)
    bubble_action.setChecked(bool(bridge.setting("floatingBubble", False)))
    bubble_action.toggled.connect(lambda on: bridge.saveSetting("floatingBubble", on))
    bridge.settingsChanged.connect(lambda: bubble_action.setChecked(bool(bridge.setting("floatingBubble", False))))
    menu.addAction(bubble_action)

    settings_window = {}

    def open_settings():
        # Look the window up every time: after it's closed once, Python's handle
        # to it can go stale (the window itself still exists, just hidden).
        win = next((w for w in QGuiApplication.topLevelWindows() if w.objectName() == "argosSettings"), None)
        if win is None:
            comp = QQmlComponent(engine, QUrl.fromLocalFile(str(HERE / "qml" / "SettingsWindow.qml")))
            win = comp.createWithInitialProperties(
                {"settingsPage": QUrl.fromLocalFile(str(PLUGIN / "DuxAISettings.qml"))})
            if win is None:
                log("Settings window failed:", [e.toString() for e in comp.errors()])
                return
            engine.setObjectOwnership(win, QQmlEngine.CppOwnership)
            settings_window["component"] = comp
        win.setIcon(argos_icon())     # the dog, in the taskbar and Alt+Tab
        win.show()
        if IS_WINDOWS:
            # Windows takes the taskbar icon from the window's taskbar identity,
            # not from the window icon: give the settings window its own.
            try:
                pythonw = Path(sys.executable).with_name("pythonw.exe")
                winutil.set_taskbar_identity(int(win.winId()), "Mateo1844.Argos.Settings",
                                             str(duxai.DATA_DIR / "argos.ico"), "Argos settings",
                                             f'"{pythonw}" "{Path(__file__).resolve()}"')
            except Exception as exc:  # noqa: BLE001 - cosmetic
                log("Taskbar icon failed:", exc)
        win.raise_()
        win.requestActivate()
        bridge.forceForeground(win)

    menu.addAction("Settings…", open_settings)

    # Argos's own notification card.
    toast_comp = QQmlComponent(engine, QUrl.fromLocalFile(str(HERE / "qml" / "Toast.qml")))
    toast = toast_comp.create()
    if toast is not None:
        engine.setObjectOwnership(toast, QQmlEngine.CppOwnership)
        toast.actionClicked.connect(lambda key: open_settings() if key == "settings" else None)
        bridge.toast = toast
    else:
        log("Notification card failed:", [e.toString() for e in toast_comp.errors()])
    menu.addSeparator()
    menu.addAction("Quit", app.quit)
    tray.setContextMenu(menu)
    tray.activated.connect(lambda reason: bridge.action.emit("toggle")
                           if reason == QSystemTrayIcon.Trigger else None)
    tray.show()

    # Remember the last window you used (for "this file/page" + screenshots).
    tracker = QTimer(app)
    tracker.timeout.connect(bridge.track_window)
    tracker.start(400)

    # Global shortcuts (in a background thread; presses come back as signals).
    if IS_WINDOWS:
        hotkeys = {name: bridge.setting(name, default) for name, default in DEFAULT_HOTKEYS.items()}
        names = {"hotkeyCapture": "capture", "hotkeyText": "text", "hotkeyChat": "chat"}
        errors = []

        def on_error(name, text):
            errors.append(text)
            log("Shortcut problem:", text)

        threading.Thread(target=winutil.hotkey_loop, daemon=True,
                         args=(hotkeys, lambda name: bridge.action.emit(names[name]), on_error)).start()
        QTimer.singleShot(1500, lambda: errors and bridge.show_toast(
            "Shortcut already in use" if len(errors) == 1 else "Some shortcuts are already in use",
            "\n".join(errors) + "\nPick another one in Settings.", True, "Open settings", "settings"))

    log("Started")
    app._keep = (tray, menu, tracker, settings_window, open_settings, engine, component, widget,
                 toast_comp, toast)   # keep alive
    return app, bridge, engine, widget


def main():
    if "--write-icon" in sys.argv:
        # Used by install.ps1: only write duxai.ico (for the Start menu shortcut).
        app = QApplication(sys.argv)
        write_icon_files(Bridge(app))
        print(duxai.DATA_DIR / "duxai.ico")
        return
    app, *_ = build()
    sys.exit(app.exec())


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:  # noqa: BLE001 - pythonw has no console, so log it
        log(traceback.format_exc())
        startup_error("Argos crashed while starting:\n\n" + traceback.format_exc()[-1500:] +
                      f"\n\nFull log: {LOG_FILE}")
