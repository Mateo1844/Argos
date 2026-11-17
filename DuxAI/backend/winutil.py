"""Windows-only helpers for Argos, using only ctypes (no extra packages).

Used by the backend (screenshots for the view_screen tool) and by the
Windows app (active window, selected text, global hotkeys).

    foreground_window()        handle of the window in front
    window_info(hwnd)          {"app": "Chrome", "title": "...", "pid": 1234}
    screenshot(path, hwnd)     PNG of a window (even if covered) or its monitor
    copy_selection_keys()      wait until Win/Shift are released, then press Ctrl+C
    parse_hotkey("Win+Shift+A") -> (modifiers, virtual key)
"""

import ctypes
import os
import time
from ctypes import wintypes
from pathlib import Path

user32 = ctypes.WinDLL("user32", use_last_error=True)
gdi32 = ctypes.WinDLL("gdi32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
dwmapi = ctypes.WinDLL("dwmapi")

# Declare argument types so 64-bit handles are not cut off.
HWND, HDC, HBITMAP = wintypes.HWND, wintypes.HDC, wintypes.HBITMAP
user32.GetForegroundWindow.restype = HWND
user32.GetWindowTextLengthW.argtypes = [HWND]
user32.GetWindowTextW.argtypes = [HWND, wintypes.LPWSTR, ctypes.c_int]
user32.GetWindowThreadProcessId.argtypes = [HWND, ctypes.POINTER(wintypes.DWORD)]
user32.GetWindowRect.argtypes = [HWND, ctypes.POINTER(wintypes.RECT)]
user32.IsIconic.argtypes = [HWND]
user32.IsWindow.argtypes = [HWND]
user32.GetWindowDC.argtypes = [HWND]
user32.GetWindowDC.restype = HDC
user32.ReleaseDC.argtypes = [HWND, HDC]
user32.PrintWindow.argtypes = [HWND, HDC, wintypes.UINT]
user32.SetForegroundWindow.argtypes = [HWND]
user32.MonitorFromWindow.argtypes = [HWND, wintypes.DWORD]
user32.MonitorFromWindow.restype = wintypes.HMONITOR
user32.GetMonitorInfoW.argtypes = [wintypes.HMONITOR, ctypes.c_void_p]
user32.GetAsyncKeyState.argtypes = [ctypes.c_int]
user32.GetAsyncKeyState.restype = ctypes.c_short
gdi32.CreateCompatibleDC.argtypes = [HDC]
gdi32.CreateCompatibleDC.restype = HDC
gdi32.CreateCompatibleBitmap.argtypes = [HDC, ctypes.c_int, ctypes.c_int]
gdi32.CreateCompatibleBitmap.restype = HBITMAP
gdi32.SelectObject.argtypes = [HDC, ctypes.c_void_p]
gdi32.GetDIBits.argtypes = [HDC, HBITMAP, wintypes.UINT, wintypes.UINT, ctypes.c_void_p, ctypes.c_void_p,
                            wintypes.UINT]
gdi32.DeleteObject.argtypes = [ctypes.c_void_p]
gdi32.DeleteDC.argtypes = [HDC]
kernel32.OpenProcess.restype = wintypes.HANDLE
kernel32.QueryFullProcessImageNameW.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR,
                                                ctypes.POINTER(wintypes.DWORD)]
kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
dwmapi.DwmGetWindowAttribute.argtypes = [HWND, wintypes.DWORD, ctypes.c_void_p, wintypes.DWORD]

# Real pixel coordinates on scaled (125%, 150%) screens.
try:
    user32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))   # per-monitor v2
except (AttributeError, OSError):
    pass

# Friendlier names for common programs (exe name -> app name).
APP_NAMES = {
    "msedge": "Edge", "chrome": "Chrome", "firefox": "Firefox", "brave": "Brave", "opera": "Opera",
    "explorer": "File Explorer", "code": "VS Code", "winword": "Word", "excel": "Excel",
    "powerpnt": "PowerPoint", "onenote": "OneNote", "acrord32": "Acrobat Reader", "acrobat": "Acrobat",
    "sumatrapdf": "SumatraPDF", "ms-teams": "Teams", "teams": "Teams", "vlc": "VLC",
    "windowsterminal": "Terminal", "matlab": "MATLAB", "pycharm64": "PyCharm", "notepad": "Notepad",
}


# ---------------------------------------------------------------- windows --

def foreground_window():
    return user32.GetForegroundWindow() or 0


def _process_name(pid):
    handle = kernel32.OpenProcess(0x1000, False, pid)   # PROCESS_QUERY_LIMITED_INFORMATION
    if not handle:
        return ""
    try:
        size = wintypes.DWORD(1024)
        buf = ctypes.create_unicode_buffer(size.value)
        if kernel32.QueryFullProcessImageNameW(handle, 0, buf, ctypes.byref(size)):
            return Path(buf.value).stem
        return ""
    finally:
        kernel32.CloseHandle(handle)


def window_info(hwnd):
    """App name, title and process id of a window."""
    if not hwnd or not user32.IsWindow(hwnd):
        return {"app": "", "title": "", "pid": 0}
    length = user32.GetWindowTextLengthW(hwnd)
    buf = ctypes.create_unicode_buffer(length + 1)
    user32.GetWindowTextW(hwnd, buf, length + 1)
    pid = wintypes.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    exe = _process_name(pid.value)
    app = APP_NAMES.get(exe.lower(), exe[:1].upper() + exe[1:])
    return {"app": app, "title": buf.value, "pid": pid.value}


_WNDENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, HWND, wintypes.LPARAM)
user32.EnumWindows.argtypes = [_WNDENUMPROC, wintypes.LPARAM]
user32.IsWindowVisible.argtypes = [HWND]
user32.ShowWindow.argtypes = [HWND, ctypes.c_int]


def hide_windows_of(pid):
    """Hide all visible windows of process `pid` (Argos itself, during a
    screenshot). Returns them, for show_windows()."""
    found = []

    def callback(hwnd, _lparam):
        owner = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        if owner.value == pid and user32.IsWindowVisible(hwnd):
            found.append(hwnd)
        return True

    user32.EnumWindows(_WNDENUMPROC(callback), 0)
    for hwnd in found:
        user32.ShowWindow(hwnd, 0)    # SW_HIDE
    return found


def show_windows(hwnds):
    for hwnd in hwnds:
        user32.ShowWindow(hwnd, 8)    # SW_SHOWNA: show again without taking focus


def set_foreground(hwnd):
    if hwnd and user32.IsWindow(hwnd):
        user32.SetForegroundWindow(hwnd)


# ------------------------------------------------------- taskbar identity --

class _GUID(ctypes.Structure):
    _fields_ = [("Data1", wintypes.DWORD), ("Data2", wintypes.WORD), ("Data3", wintypes.WORD),
                ("Data4", ctypes.c_ubyte * 8)]

    @classmethod
    def parse(cls, text):
        import uuid
        u = uuid.UUID(text)
        g = cls(u.time_low, u.time_mid, u.time_hi_version)
        g.Data4[:] = list(u.bytes[8:])
        return g


class _PROPERTYKEY(ctypes.Structure):
    _fields_ = [("fmtid", _GUID), ("pid", wintypes.DWORD)]


class _PROPVARIANT(ctypes.Structure):   # only the "text" kind (VT_LPWSTR) is used here
    _fields_ = [("vt", wintypes.USHORT), ("r1", wintypes.USHORT), ("r2", wintypes.USHORT),
                ("r3", wintypes.USHORT), ("pwszVal", ctypes.c_wchar_p), ("pad", ctypes.c_void_p)]


_APPUSERMODEL = "{9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}"
_IID_IPROPERTYSTORE = "{886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99}"


def set_taskbar_identity(hwnd, app_id, icon_path, display_name, relaunch_command):
    """Give one window its own taskbar button identity + icon (like Chrome
    profiles do). Without this, Windows shows the Python icon."""
    shell32 = ctypes.WinDLL("shell32")
    ole32 = ctypes.WinDLL("ole32")
    ole32.CoInitialize(None)
    store = ctypes.c_void_p()
    iid = _GUID.parse(_IID_IPROPERTYSTORE)
    hr = shell32.SHGetPropertyStoreForWindow(HWND(hwnd), ctypes.byref(iid), ctypes.byref(store))
    if hr != 0 or not store:
        return False
    vtable = ctypes.cast(store, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p)))[0]
    set_value = ctypes.WINFUNCTYPE(ctypes.c_long, ctypes.c_void_p, ctypes.POINTER(_PROPERTYKEY),
                                   ctypes.POINTER(_PROPVARIANT))(vtable[6])
    commit = ctypes.WINFUNCTYPE(ctypes.c_long, ctypes.c_void_p)(vtable[7])
    release = ctypes.WINFUNCTYPE(ctypes.c_ulong, ctypes.c_void_p)(vtable[2])
    try:
        # RelaunchCommand (2), RelaunchIconResource (3), RelaunchDisplayNameResource (4), then ID (5)
        for pid, value in ((2, relaunch_command), (3, f"{icon_path},0"), (4, display_name), (5, app_id)):
            key = _PROPERTYKEY(_GUID.parse(_APPUSERMODEL), pid)
            var = _PROPVARIANT(vt=31, pwszVal=value)   # 31 = VT_LPWSTR
            set_value(store, ctypes.byref(key), ctypes.byref(var))
        commit(store)
    finally:
        release(store)
    return True


# ------------------------------------------------------------ screenshots --

class _BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [("biSize", wintypes.DWORD), ("biWidth", ctypes.c_long), ("biHeight", ctypes.c_long),
                ("biPlanes", wintypes.WORD), ("biBitCount", wintypes.WORD),
                ("biCompression", wintypes.DWORD), ("biSizeImage", wintypes.DWORD),
                ("biXPelsPerMeter", ctypes.c_long), ("biYPelsPerMeter", ctypes.c_long),
                ("biClrUsed", wintypes.DWORD), ("biClrImportant", wintypes.DWORD)]


class _MONITORINFO(ctypes.Structure):
    _fields_ = [("cbSize", wintypes.DWORD), ("rcMonitor", wintypes.RECT),
                ("rcWork", wintypes.RECT), ("dwFlags", wintypes.DWORD)]


def _window_rects(hwnd):
    """(outer rect, visible rect): Windows 10/11 windows have invisible borders."""
    outer = wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(outer))
    visible = wintypes.RECT()
    if dwmapi.DwmGetWindowAttribute(hwnd, 9, ctypes.byref(visible), ctypes.sizeof(visible)) != 0:
        visible = outer   # DWMWA_EXTENDED_FRAME_BOUNDS not available
    return outer, visible


def _print_window(hwnd):
    """Image of a window's own content, also when other windows cover it."""
    from PIL import Image
    outer, visible = _window_rects(hwnd)
    w, h = outer.right - outer.left, outer.bottom - outer.top
    if w <= 0 or h <= 0:
        return None
    hdc_win = user32.GetWindowDC(hwnd)
    hdc_mem = gdi32.CreateCompatibleDC(hdc_win)
    bmp = gdi32.CreateCompatibleBitmap(hdc_win, w, h)
    try:
        gdi32.SelectObject(hdc_mem, bmp)
        if not user32.PrintWindow(hwnd, hdc_mem, 2):    # 2 = PW_RENDERFULLCONTENT (browsers, apps)
            return None
        info = _BITMAPINFOHEADER(biSize=ctypes.sizeof(_BITMAPINFOHEADER), biWidth=w, biHeight=-h,
                                 biPlanes=1, biBitCount=32, biCompression=0)
        buf = ctypes.create_string_buffer(w * h * 4)
        gdi32.GetDIBits(hdc_mem, bmp, 0, h, buf, ctypes.byref(info), 0)
        img = Image.frombuffer("RGB", (w, h), buf, "raw", "BGRX", 0, 1)
    finally:
        gdi32.DeleteObject(bmp)
        gdi32.DeleteDC(hdc_mem)
        user32.ReleaseDC(hwnd, hdc_win)
    # Cut off the invisible border around the window.
    img = img.crop((visible.left - outer.left, visible.top - outer.top,
                    visible.right - outer.left, visible.bottom - outer.top))
    if img.getbbox() is None:   # completely black: this app can't be captured this way
        return None
    return img


def _monitor_rect(hwnd):
    info = _MONITORINFO(cbSize=ctypes.sizeof(_MONITORINFO))
    monitor = user32.MonitorFromWindow(hwnd or None, 2)   # MONITOR_DEFAULTTONEAREST
    user32.GetMonitorInfoW(monitor, ctypes.byref(info))
    r = info.rcMonitor
    return (r.left, r.top, r.right, r.bottom)


def screenshot(path, hwnd=None, full=False):
    """Save a PNG of window `hwnd` (default: the foreground window) or, with
    full=True, of the whole monitor it is on. Returns True on success."""
    from PIL import ImageGrab
    hwnd = hwnd if hwnd and user32.IsWindow(hwnd) else foreground_window()
    img = None
    if not full and hwnd and not user32.IsIconic(hwnd):
        img = _print_window(hwnd)
        if img is None:   # fall back to grabbing that part of the screen
            _, visible = _window_rects(hwnd)
            img = ImageGrab.grab(bbox=(visible.left, visible.top, visible.right, visible.bottom),
                                 all_screens=True)
    if img is None:
        img = ImageGrab.grab(bbox=_monitor_rect(hwnd), all_screens=True)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    return Path(path).is_file()


# ---------------------------------------------------------- selected text --

VK = {"SHIFT": 0x10, "CTRL": 0x11, "ALT": 0x12, "LWIN": 0x5B, "RWIN": 0x5C}


def modifiers_down():
    return any(user32.GetAsyncKeyState(vk) & 0x8000 for vk in VK.values())


def copy_selection_keys(wait_release=1.5):
    """Press Ctrl+C in the window in front. First waits (max `wait_release`
    seconds) until the keys of the hotkey (Win, Shift, ...) are released,
    otherwise Windows would see Win+Shift+Ctrl+C."""
    deadline = time.time() + wait_release
    while modifiers_down() and time.time() < deadline:
        time.sleep(0.02)
    keyup = 0x0002
    user32.keybd_event(VK["CTRL"], 0, 0, 0)
    user32.keybd_event(ord("C"), 0, 0, 0)
    user32.keybd_event(ord("C"), 0, keyup, 0)
    user32.keybd_event(VK["CTRL"], 0, keyup, 0)


# ---------------------------------------------------------------- hotkeys --

MODS = {"alt": 0x1, "ctrl": 0x2, "control": 0x2, "shift": 0x4, "win": 0x8, "super": 0x8, "meta": 0x8}
NAMED_KEYS = {"space": 0x20, "enter": 0x0D, "tab": 0x09, "esc": 0x1B,
              **{f"f{i}": 0x6F + i for i in range(1, 13)}}


def parse_hotkey(text):
    """'Win+Shift+A' -> (modifiers, virtual key) for RegisterHotKey. None if invalid."""
    parts = [p.strip().lower() for p in (text or "").split("+") if p.strip()]
    if not parts:
        return None
    mods = 0
    for p in parts[:-1]:
        if p not in MODS:
            return None
        mods |= MODS[p]
    key = parts[-1]
    if len(key) == 1 and key.isalnum():
        vk = ord(key.upper())
    elif key in NAMED_KEYS:
        vk = NAMED_KEYS[key]
    else:
        return None
    return mods | 0x4000, vk   # 0x4000 = MOD_NOREPEAT: holding the keys fires once


class _MSG(ctypes.Structure):
    _fields_ = [("hwnd", HWND), ("message", wintypes.UINT), ("wParam", wintypes.WPARAM),
                ("lParam", wintypes.LPARAM), ("time", wintypes.DWORD), ("pt", wintypes.POINT)]


def hotkey_loop(hotkeys, on_hotkey, on_error):
    """Register hotkeys {name: "Win+Shift+A"} and call on_hotkey(name) when pressed.

    Blocks forever: run it in a background thread. on_error(name, text) is
    called for keys that are invalid or already used by another program.
    """
    names = {}
    for i, (name, text) in enumerate(hotkeys.items(), start=1):
        if not text:
            continue
        parsed = parse_hotkey(text)
        if parsed is None:
            on_error(name, f"'{text}' is not a valid shortcut")
            continue
        if not user32.RegisterHotKey(None, i, parsed[0], parsed[1]):
            on_error(name, f"{text} is already used by Windows or another program")
            continue
        names[i] = name
    msg = _MSG()
    while user32.GetMessageW(ctypes.byref(msg), None, 0, 0) > 0:
        if msg.message == 0x0312 and msg.wParam in names:   # WM_HOTKEY
            on_hotkey(names[msg.wParam])


if __name__ == "__main__" and os.name == "nt":
    print(window_info(foreground_window()))
