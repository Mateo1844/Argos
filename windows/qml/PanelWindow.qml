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

    readonly property rect area: dux.primaryWorkArea()   // main screen without the taskbar

    transientParent: null   // its own top-level window
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    width: implicitWidth
    height: implicitHeight
    x: anchors.right ? area.x + area.width - width - margins.right : area.x + margins.left
    y: anchors.bottom ? area.y + area.height - height - margins.bottom : area.y + margins.top
}
