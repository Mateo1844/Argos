"""DUX-AI for Windows: Claude in your system tray.

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
        ctypes.windll.user32.MessageBoxW(None, text, "DUX-AI could not start", 0x10)
    print(text, file=sys.stderr)
    raise SystemExit(1)


try:
    import PySide6  # noqa: F401
except ImportError:
    startup_error("PySide6 is not installed for this Python:\n" + sys.executable +
                  "\n\nRun windows\\install.ps1 again and check its output, or start DUX-AI from the "
                  "Start menu entry the installer made.")

from PySide6.QtCore import QObject, QPoint, QRect, Qt, QTimer, QUrl, Property, Signal, Slot, QMimeData
from PySide6.QtGui import QAction, QColor, QFont, QFontDatabase, QGuiApplication, QIcon, QPainter, QPen, QPixmap
from PySide6.QtQml import QJSValue, QQmlComponent, QQmlEngine, qmlRegisterType
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon, QWidget

HERE = Path(__file__).resolve().parent            # .../DUX-AI/windows
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
RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"


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

    def __init__(self, app):
        super().__init__()
        self.app = app
        self.tray = None
        self.last_hwnd = 0               # last window you used that isn't DUX-AI
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
    textFont = Property(str, lambda self: "Segoe UI" if IS_WINDOWS else "", constant=True)

    # --- popup helpers ---
    def _get_hold(self):
        return self._hold

    holdPopup = Property(bool, _get_hold, notify=holdPopupChanged)

    @Slot(result=QRect)
    def primaryWorkArea(self):
        """Usable area (without taskbar) of the main screen."""
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
        if self.tray:
            icon = QSystemTrayIcon.Warning if error else QSystemTrayIcon.Information
            self.tray.showMessage("DUX-AI", (message + ("\n" + details if details else "")).strip(), icon, 4000)

    # --- start with Windows (registry "Run" key, current user only) ---
    def _get_autostart(self):
        if not IS_WINDOWS:
            return False
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY) as key:
                winreg.QueryValueEx(key, "DUX-AI")
                return True
        except OSError:
            return False

    startWithWindows = Property(bool, _get_autostart, notify=startWithWindowsChanged)

    @Slot(bool)
    def setStartWithWindows(self, on):
        if not IS_WINDOWS:
            return
        import winreg
        pythonw = Path(sys.executable).with_name("pythonw.exe")
        command = f'"{pythonw if pythonw.exists() else sys.executable}" "{Path(__file__).resolve()}"'
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY, 0, winreg.KEY_SET_VALUE) as key:
            if on:
                winreg.SetValueEx(key, "DUX-AI", 0, winreg.REG_SZ, command)
            else:
                try:
                    winreg.DeleteValue(key, "DUX-AI")
                except OSError:
                    pass
        self.startWithWindowsChanged.emit()

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
            return   # DUX-AI itself, the desktop, or the taskbar: keep the previous window
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

def tray_icon(bridge):
    """Orange circle with the logo (DuxAI/assets/logo.svg, made white) or a sparkle."""
    size = 64
    pix = QPixmap(size, size)
    pix.fill(Qt.transparent)
    p = QPainter(pix)
    p.setRenderHint(QPainter.Antialiasing)
    p.setPen(Qt.NoPen)
    p.setBrush(QColor(ACCENT))
    p.drawEllipse(0, 0, size, size)
    logo = PLUGIN / "assets" / "logo.svg"
    if logo.exists():
        from PySide6.QtSvg import QSvgRenderer
        glyph = QPixmap(size, size)
        glyph.fill(Qt.transparent)
        gp = QPainter(glyph)
        QSvgRenderer(str(logo)).render(gp, QRect(14, 14, size - 28, size - 28).toRectF())
        gp.setCompositionMode(QPainter.CompositionMode_SourceIn)   # paint it white
        gp.fillRect(glyph.rect(), Qt.white)
        gp.end()
        p.drawPixmap(0, 0, glyph)
    else:
        font = QFont(bridge.iconFont)
        font.setPixelSize(40)
        p.setFont(font)
        p.setPen(Qt.white)
        p.drawText(pix.rect(), Qt.AlignCenter, bridge.icon("auto_awesome"))
    p.end()
    return QIcon(pix)


# ================================================================== main ==

def build():
    """Create the app, chat window, tray and shortcuts. Returns (app, bridge, engine, widget)."""
    os.environ.setdefault("QT_QUICK_CONTROLS_MATERIAL_THEME", "Dark")
    os.environ.setdefault("QT_QUICK_CONTROLS_MATERIAL_ACCENT", ACCENT)
    QQuickStyle.setStyle("Material")
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)    # it lives in the tray
    app.setApplicationName("DUX-AI")

    bridge = Bridge(app)
    shims.BRIDGE = bridge

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
        raise SystemExit("Could not load the chat window:\n" + errors)

    # Tray icon + menu.
    tray = QSystemTrayIcon(tray_icon(bridge), app)
    tray.setToolTip("DUX-AI: Claude")
    bridge.tray = tray
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
        if "w" not in settings_window:
            comp = QQmlComponent(engine, QUrl.fromLocalFile(str(HERE / "qml" / "SettingsWindow.qml")))
            win = comp.createWithInitialProperties(
                {"settingsPage": QUrl.fromLocalFile(str(PLUGIN / "DuxAISettings.qml"))})
            if win is None:
                log("Settings window failed:", [e.toString() for e in comp.errors()])
                return
            settings_window["w"] = win
        settings_window["w"].show()
        settings_window["w"].raise_()
        settings_window["w"].requestActivate()

    menu.addAction("Settings…", open_settings)
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
        QTimer.singleShot(1500, lambda: errors and bridge.notify(
            "Some shortcuts could not be set", "\n".join(errors) + "\nChange them in Settings.", True))

    log("Started")
    app._keep = (tray, menu, tracker, settings_window, open_settings, engine, component, widget)   # keep alive
    return app, bridge, engine, widget


def main():
    app, *_ = build()
    sys.exit(app.exec())


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:  # noqa: BLE001 - pythonw has no console, so log it
        log(traceback.format_exc())
        startup_error("DUX-AI crashed while starting:\n\n" + traceback.format_exc()[-1500:] +
                      f"\n\nFull log: {LOG_FILE}")
