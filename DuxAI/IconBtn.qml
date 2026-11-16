// Small round icon button used in the chat window.
import QtQuick
import qs.Common
import qs.DCommon.Widgets

Rectangle {
    id: btn

    property string icon: ""
    property bool active: false
    property bool filled: false
    property int iconSize: 18
    property color iconColor: Theme.onSurfaceVariant
    signal clicked

    implicitWidth: 32
    implicitHeight: 32
    radius: width / 2
    color: active ? Theme.withAlpha(Theme.primary, 0.18) : (mouse.containsMouse ? Theme.withAlpha(Theme.onSurface, 0.08) : "transparent")
    opacity: enabled ? 1 : 0.4

    DIcon {
        anchors.centerIn: parent
        name: btn.icon
        size: btn.iconSize
        filled: btn.filled
        color: btn.active ? Theme.primary : btn.iconColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
