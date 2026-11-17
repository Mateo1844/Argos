// Windows stand-in for Quickshell's PanelWindow (used for the floating bubble
// and the approval card): a borderless always-on-top window placed with
// anchors + margins relative to the screen's work area (above the taskbar).
import QtQuick
import QtQuick.Window

Window {
    id: panel

    property real implicitWidth: 100
    property real implicitHeight: 100
    property int exclusionMode: 0
    // Typed groups, so "anchors { top: true }" and "margins { right: 12 }" work.
    component Edges: QtObject {
        property bool top: false
        property bool bottom: false
        property bool left: false
        property bool right: false
    }
    component Margins: QtObject {
        property real top: 0
        property real bottom: 0
        property real left: 0
        property real right: 0
    }
    property Edges anchors: Edges {}
    property Margins margins: Margins {}

    property var mask: null      // "mask: Region {}" = clicks go through the window

    // The screen it should be on (like Quickshell's "screen:"). Windows puts a
    // window on whatever monitor its x/y fall on, so it is placed in that
    // screen's work area (without the taskbar).
    property var screen: null
    readonly property rect area: dux.workAreaOf(screen ? screen.name : "")
    readonly property bool fillWidth: anchors.left && anchors.right
    readonly property bool fillHeight: anchors.top && anchors.bottom

    transientParent: null   // its own top-level window
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
           | (mask ? Qt.WindowTransparentForInput : 0)
    color: "transparent"
    width: fillWidth ? area.width - margins.left - margins.right : implicitWidth
    height: fillHeight ? area.height - margins.top - margins.bottom : implicitHeight
    // Placed by anchors + margins, and always kept inside the work area. Not a
    // binding: when the window resizes, Windows keeps the old position, so it's
    // placed again on every change (and once more a moment after a resize).
    function place() {
        x = Math.min(Math.max(anchors.left || !anchors.right ? area.x + margins.left
                                                            : area.x + area.width - width - margins.right,
                              area.x), area.x + area.width - width);
        y = Math.min(Math.max(anchors.top || !anchors.bottom ? area.y + margins.top
                                                            : area.y + area.height - height - margins.bottom,
                              area.y), area.y + area.height - height);
    }
    Component.onCompleted: place()
    onAreaChanged: place()
    onVisibleChanged: if (visible) place()
    onWidthChanged: { place(); Qt.callLater(place); }
    onHeightChanged: { place(); Qt.callLater(place); }
    Connections {
        target: panel.margins
        function onLeftChanged() { panel.place(); }
        function onRightChanged() { panel.place(); }
        function onTopChanged() { panel.place(); }
        function onBottomChanged() { panel.place(); }
    }
}
