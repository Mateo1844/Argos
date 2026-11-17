// Windows stand-in for DMS's PluginComponent.
//
// DuxAIWidget.qml (the same file DMS uses) is built on this. Instead of a
// bar pill + popout, the chat opens in a borderless window above the tray.
import QtQuick
import QtQuick.Window
import qs.Common

Item {
    id: base

    readonly property string hostPlatform: "windows"   // lets the widget know where it runs
    property string pluginId: "duxAi"
    property string layerNamespacePlugin: ""
    property var pluginData: dux.settings              // saved in settings.json
    property var pluginService: QtObject {
        function savePluginData(id, key, value) {
            dux.saveSetting(key, value);
            return true;
        }
    }

    property real popoutWidth: 400
    property real popoutHeight: 400
    property Component horizontalBarPill: null
    property Component verticalBarPill: null
    property Component popoutContent: null
    property var pillClickAction: null
    property var pillRightClickAction: null
    property int iconSize: 22
    property int iconSizeLarge: 26
    property real barThickness: 0
    property var barConfig: null
    property var parentScreen: Qt.application.screens.length ? Qt.application.screens[0] : null

    readonly property bool interactionActive: popup.visible

    function triggerPopout() {
        if (popup.visible)
            closePopout();
        else
            showPopup();
    }
    function closePopout() {
        popup.visible = false;
    }
    // Called by DuxAIWidget.qml when the floating bubble is turned off.
    function closeBubblePopup() {
        if (popupAnchor)
            closePopout();
    }
    // Set when the chat is opened from the floating bubble: open it next to the bubble.
    property var popupAnchor: null

    // Called by DuxAIWidget.qml when the floating bubble is clicked.
    // openOnly = true: don't close it if it's already open.
    function showPopupNear(bubbleX, bubbleY, bubbleSize, openOnly) {
        popupAnchor = { x: bubbleX, y: bubbleY, size: bubbleSize };
        if (popup.visible && !openOnly)
            closePopout();
        else
            showPopup();
    }

    // (Not called "openPopout": DuxAIWidget.qml has its own function with that name.)
    function showPopup() {
        const area = dux.workArea();
        if (popupAnchor) {
            // Next to the bubble: above it if there's room, otherwise below; inside the screen.
            const a = popupAnchor;
            const above = a.y - popup.height - 8;
            popup.x = Math.min(Math.max(a.x + a.size - popup.width, area.x), area.x + area.width - popup.width);
            popup.y = above >= area.y ? above : Math.min(a.y + a.size + 8, area.y + area.height - popup.height);
        } else {
            // Bottom-right of the screen with the mouse, just above the taskbar.
            popup.x = area.x + area.width - popup.width - 12;
            popup.y = area.y + area.height - popup.height - 12;
        }
        popup.visible = true;
        popup.raise();
        popup.requestActivate();
        dux.forceForeground(popup);
    }

    // Tray icon, menu and shortcuts (from the Python app).
    Connections {
        target: dux
        function onAction(name) {
            base.popupAnchor = null;   // tray / shortcuts: open above the tray again
            if (name === "toggle") {
                // Clicking the tray icon while the chat is open first closes it
                // (focus lost); that same click must not open it again.
                if (popup.visible || Date.now() - popup.hiddenAt > 300)
                    base.triggerPopout();
            } else if (typeof base.openWithMode === "function") {
                base.openWithMode(name);     // "chat", "capture" or "text" (defined in DuxAIWidget.qml)
            } else {
                base.showPopup();
            }
        }
    }

    Window {
        id: popup
        property real hiddenAt: 0
        readonly property real pad: PopoutMetrics.contentPadding

        // Its own top-level window (not tied to an invisible parent, or it would never show).
        transientParent: null
        flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        color: "transparent"
        width: base.popoutWidth
        height: (content.item ? content.item.implicitHeight : base.popoutHeight) + 2 * pad
        visible: false
        title: "DUX-AI"

        // Like a flyout: clicking somewhere else closes it.
        onActiveChanged: {
            if (!active && visible && !dux.holdPopup) {
                hiddenAt = Date.now();
                visible = false;
            }
        }
        onVisibleChanged: {
            if (!visible)
                hiddenAt = Date.now();
        }

        Rectangle {
            width: popup.width
            height: popup.height
            radius: Theme.windowRadius
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.withAlpha(Theme.onSurface, 0.08)
        }

        Loader {
            id: content
            x: popup.pad
            y: popup.pad
            width: popup.width - 2 * popup.pad
            focus: true
            sourceComponent: base.popoutContent
            Keys.onEscapePressed: base.closePopout()
        }
    }
}
