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
    property real barSpacing: 0
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

    property int growOrigin: Item.BottomRight

    // Screen area the chat is placed in (without the taskbar). Kept while it's open,
    // so it can be placed again when its size changes.
    property rect popupArea: Qt.rect(0, 0, 1920, 1040)

    // Put the chat in place. Called again whenever its size changes (it grows
    // with its content), so it never slides under the taskbar or over the bubble.
    function placePopup() {
        const area = popupArea;
        const w = popup.width, h = popup.height, gap = 8;
        const clampX = x => Math.min(Math.max(x, area.x), area.x + area.width - w);
        const clampY = y => Math.min(Math.max(y, area.y), area.y + area.height - h);
        if (popupAnchor) {
            // In the bubble's place (the bubble hides meanwhile): the chat's corner
            // goes where the bubble was, so it looks like the bubble grew into it.
            const a = popupAnchor;
            const rightHalf = a.x + a.size / 2 > area.x + area.width / 2;
            const lowerHalf = a.y + a.size / 2 > area.y + area.height / 2;
            popup.x = clampX(rightHalf ? a.x + a.size - w : a.x);
            popup.y = clampY(lowerHalf ? a.y + a.size - h : a.y);
            growOrigin = lowerHalf ? (rightHalf ? Item.BottomRight : Item.BottomLeft)
                                   : (rightHalf ? Item.TopRight : Item.TopLeft);
        } else {
            // Bottom-right of the screen with the mouse, just above the taskbar.
            popup.x = area.x + area.width - w - 12;
            popup.y = clampY(area.y + area.height - h - 12);
        }
    }

    // (Not called "openPopout": DuxAIWidget.qml has its own function with that name.)
    function showPopup() {
        popupArea = popupAnchor ? dux.workAreaAt(popupAnchor.x + popupAnchor.size / 2, popupAnchor.y + popupAnchor.size / 2)
                                : dux.workArea();
        placePopup();
        // Invisible until the new first frame is drawn: Windows would otherwise
        // briefly show the window's last frame from the previous time (flicker).
        popup.opacity = 0;
        if (popupAnchor) {
            frame.scale = 0.85;          // start state before it shows, so it never flashes at full size
            frame.opacity = 0;
            growAnim.restart();          // grows out of the bubble
        } else {
            frame.scale = 1;
            frame.opacity = 1;
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
        // Never taller than the screen (minus the taskbar).
        height: Math.min((content.item ? content.item.implicitHeight : base.popoutHeight) + 2 * pad, base.popupArea.height - 16)
        visible: false
        title: "Argos"
        // Placed again a moment after its size changes (the window system may
        // otherwise keep the old position).
        onHeightChanged: if (visible) Qt.callLater(base.placePopup)
        onFrameSwapped: {
            if (visible && opacity === 0)
                opacity = 1;
        }
        Component.onCompleted: dux.noTransitions(popup)
        onWidthChanged: if (visible) Qt.callLater(base.placePopup)

        // Like a flyout: clicking somewhere else closes it.
        onActiveChanged: {
            if (!active && visible && !dux.holdPopup && !(base.pinned ?? false)) {   // pinned: stays open
                hiddenAt = Date.now();
                visible = false;
            }
        }
        onVisibleChanged: {
            if (!visible)
                hiddenAt = Date.now();
        }

        Item {
            id: frame
            width: popup.width
            height: popup.height
            transformOrigin: base.growOrigin
            ParallelAnimation {
                id: growAnim
                NumberAnimation { target: frame; property: "scale"; from: 0.85; to: 1; duration: 160; easing.type: Easing.OutCubic }
                NumberAnimation { target: frame; property: "opacity"; from: 0; to: 1; duration: 120 }
            }

            Rectangle {
                anchors.fill: parent
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
}
