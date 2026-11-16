// A small rounded "chip" that opens a list of choices above itself.
// Used for the model and thinking-level pickers.
import QtQuick
import qs.Common
import qs.DCommon.Widgets

Item {
    id: chip

    property string icon: ""
    property var options: []      // [{ value: "sonnet", label: "Sonnet" }, ...]
    property string current: ""
    property bool open: false
    signal picked(string value)

    readonly property string currentLabel: {
        for (const o of options)
            if (o.value === current)
                return o.label;
        return current;
    }

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 30

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: mouse.containsMouse || chip.open ? Theme.withAlpha(Theme.onSurface, 0.12) : Theme.withAlpha(Theme.onSurface, 0.06)

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 4

            DIcon {
                visible: chip.icon !== ""
                name: chip.icon
                size: 14
                color: Theme.onSurfaceVariant
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: chip.currentLabel
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.onSurface
                anchors.verticalCenter: parent.verticalCenter
            }
            DIcon {
                name: chip.open ? "expand_more" : "expand_less"
                size: 14
                color: Theme.onSurfaceVariant
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.open = !chip.open
        }
    }

    // The menu opens upwards because the chips sit at the bottom of the window.
    Rectangle {
        id: menu
        visible: chip.open
        z: 1000
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        width: Math.max(150, list.implicitWidth + 8)
        height: list.implicitHeight + 8
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        border.color: Theme.outlineVariant
        border.width: 1

        Column {
            id: list
            x: 4
            y: 4

            Repeater {
                model: chip.options

                Rectangle {
                    required property var modelData
                    width: menu.width - 8
                    height: 34
                    radius: Theme.cornerRadius
                    color: itemMouse.containsMouse ? Theme.withAlpha(Theme.onSurface, 0.08) : "transparent"

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.onSurface
                    }
                    DIcon {
                        visible: modelData.value === chip.current
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        name: "check"
                        size: 16
                        color: Theme.primary
                    }
                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            chip.open = false;
                            chip.picked(modelData.value);
                        }
                    }
                }
            }
        }
    }
}
