"""Stand-ins for the Quickshell (Linux shell toolkit) parts that DuxAIWidget.qml uses.

DuxAIWidget.qml is the same file DMS loads on Linux. On Windows these small
Python classes play the role of Quickshell, so the chat window works unchanged:

    Quickshell.Io       Process, SplitParser      run the backend, read its JSON lines
    Quickshell.Wayland  ToplevelManager, ...      "which window is active"
    Quickshell          Quickshell, PanelWindow   copy to clipboard, small always-on-top windows
"""

import json
import sys
from enum import Enum
from pathlib import Path

from PySide6.QtCore import QEnum, QObject, QProcess, QTimer, Property, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QmlAttached, QmlElement, QmlSingleton, QmlUncreatable

# Set by the app at start-up: the bridge object (target window for screenshots).
BRIDGE = None


def python_command(cmd):
    """['python3', script, ...] -> [python.exe, script, ...] (Windows has no 'python3').

    python.exe, not the pythonw.exe Argos runs with: Windows shows a "busy"
    cursor next to the mouse for a few seconds whenever a GUI program like
    pythonw.exe starts. python.exe is a console program, and Qt starts it
    without a console window (Argos itself has no console)."""
    cmd = [str(c) for c in cmd]
    if cmd and cmd[0] in ("python3", "python"):
        console = Path(sys.executable).with_name("python.exe")
        cmd[0] = str(console if console.exists() else sys.executable)
    return cmd


# ========================================================== Quickshell.Io ==
QML_IMPORT_NAME = "Quickshell.Io"
QML_IMPORT_MAJOR_VERSION = 1


@QmlElement
class SplitParser(QObject):
    """Receives a process's output line by line (signal `read`)."""
    read = Signal(str, arguments=["data"])


@QmlElement
class Process(QObject):
    """Like Quickshell's Process: set `command`, set `running` to true to start,
    false to stop. Output lines go to `stdout` (a SplitParser)."""

    exited = Signal(int, int, arguments=["exitCode", "exitStatus"])
    runningChanged = Signal()
    commandChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._command = []
        self._stdout = None
        self._stdin_enabled = False
        self._proc = None
        self._buffer = b""

    # --- properties ---
    def _get_command(self):
        return self._command

    def _set_command(self, value):
        self._command = list(value or [])
        self.commandChanged.emit()

    command = Property("QVariantList", _get_command, _set_command, notify=commandChanged)

    def _get_stdout(self):
        return self._stdout

    def _set_stdout(self, value):
        self._stdout = value

    stdout = Property(QObject, _get_stdout, _set_stdout)

    def _get_stdin(self):
        return self._stdin_enabled

    def _set_stdin(self, value):
        self._stdin_enabled = bool(value)

    stdinEnabled = Property(bool, _get_stdin, _set_stdin)

    def _get_running(self):
        return self._proc is not None

    def _set_running(self, value):
        if value and self._proc is None:
            self._start()
        elif not value and self._proc is not None:
            self._stop()

    running = Property(bool, _get_running, _set_running, notify=runningChanged)

    # --- process handling ---
    def _start(self):
        cmd = python_command(self._command)
        if "ask" in cmd and "--" in cmd and BRIDGE and BRIDGE.last_hwnd:
            # Tell the backend which window to screenshot (not the chat window).
            cmd.insert(cmd.index("--"), f"--target-window={BRIDGE.last_hwnd}")
        self._buffer = b""
        proc = QProcess(self)
        proc.readyReadStandardOutput.connect(self._on_output)
        proc.finished.connect(self._on_finished)
        self._proc = proc
        proc.start(cmd[0], cmd[1:])
        self.runningChanged.emit()

    def _stop(self):
        # The backend stops Claude and keeps the partial answer when it reads this.
        self.write(json.dumps({"stop": True}) + "\n")
        proc = self._proc
        QTimer.singleShot(5000, lambda: proc.kill() if proc.state() != QProcess.NotRunning else None)

    @Slot(str)
    def write(self, data):
        if self._proc is not None:
            self._proc.write(data.encode("utf-8"))

    def _on_output(self):
        self._buffer += bytes(self._proc.readAllStandardOutput())
        *lines, self._buffer = self._buffer.split(b"\n")
        for line in lines:
            if self._stdout is not None:
                self._stdout.read.emit(line.decode("utf-8", "replace").rstrip("\r"))

    def _on_finished(self, code, status):
        if self._buffer and self._stdout is not None:
            self._stdout.read.emit(self._buffer.decode("utf-8", "replace"))
        self._buffer = b""
        self._proc = None
        self.runningChanged.emit()
        self.exited.emit(code, 0 if status == QProcess.NormalExit else 1)


# ===================================================== Quickshell.Wayland ==
QML_IMPORT_NAME = "Quickshell.Wayland"


@QmlElement
@QmlUncreatable("Toplevels come from ToplevelManager")
class Toplevel(QObject):
    """One window: app name + title."""

    def __init__(self, app_id="", title="", parent=None):
        super().__init__(parent)
        self._app_id, self._title = app_id, title

    appId = Property(str, lambda self: self._app_id, constant=True)
    title = Property(str, lambda self: self._title, constant=True)


@QmlElement
@QmlSingleton
class ToplevelManager(QObject):
    """activeToplevel = the last window you used that isn't Argos itself
    (kept up to date by the app's window tracker)."""

    activeToplevelChanged = Signal()
    _instance = None

    def __init__(self, parent=None):
        super().__init__(parent)
        self._active = None
        ToplevelManager._instance = self

    @staticmethod
    def create(engine):
        return ToplevelManager._instance or ToplevelManager()

    def set_active(self, app_id, title):
        self._active = Toplevel(app_id, title, self)
        self.activeToplevelChanged.emit()

    activeToplevel = Property(QObject, lambda self: self._active, notify=activeToplevelChanged)


def _ignored_setting(name):
    """A property that QML may set; the value is stored and otherwise ignored."""
    return Property("QVariant", lambda self: self._values.get(name),
                    lambda self, v: self._values.__setitem__(name, v))


class LayershellAttached(QObject):
    """WlrLayershell.* settings: only meaningful on Linux, accepted and ignored here."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self._values = {}

    namespace = _ignored_setting("namespace")
    layer = _ignored_setting("layer")
    keyboardFocus = _ignored_setting("keyboardFocus")
    exclusiveZone = _ignored_setting("exclusiveZone")


@QmlElement
@QmlUncreatable("only used as WlrLayershell.<setting>")
@QmlAttached(LayershellAttached)
class WlrLayershell(QObject):
    @staticmethod
    def qmlAttachedProperties(cls, obj):
        return LayershellAttached(obj)


@QmlElement
@QmlUncreatable("enum")
class WlrLayer(QObject):
    Layer = QEnum(Enum("Layer", {"Background": 0, "Bottom": 1, "Top": 2, "Overlay": 3}))


@QmlElement
@QmlUncreatable("enum")
class WlrKeyboardFocus(QObject):
    # Built this way because "None" can't be written as a normal Python name.
    Focus = QEnum(Enum("Focus", {"None": 0, "Exclusive": 1, "OnDemand": 2}))


# ============================================================= Quickshell ==
QML_IMPORT_NAME = "Quickshell"


@QmlElement
@QmlUncreatable("enum")
class ExclusionMode(QObject):
    Mode = QEnum(Enum("Mode", {"Normal": 0, "Ignore": 1, "Auto": 2}))


@QmlElement
@QmlSingleton
class Quickshell(QObject):
    """Only execDetached is used: for "dms cl copy <text>" (copy an answer)."""

    @staticmethod
    def create(engine):
        return Quickshell()

    @Slot("QVariantList")
    def execDetached(self, command):
        command = [str(c) for c in command]
        if command[:3] == ["dms", "cl", "copy"] and len(command) > 3:
            QGuiApplication.clipboard().setText(command[3])
        else:
            QProcess.startDetached(command[0], command[1:])
