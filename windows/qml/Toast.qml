// DUX-AI's own notification: a small card above the tray (instead of a
// Windows notification, which would say it comes from "Python").
import QtQuick
import QtQuick.Window
import qs.Common
import qs.DCommon.Widgets

Window {
    id: toast

    property string heading: ""
    property string message: ""
    property bool isError: false
    property string actionLabel: ""
    property string actionKey: ""
    signal actionClicked(string key)

    function showToast(heading, message, isError, actionLabel, actionKey) {
        toast.heading = heading;
        toast.message = message;
        toast.isError = isError;
        toast.actionLabel = actionLabel || "";
        toast.actionKey = actionKey || "";
        Qt.callLater(() => {
            const a = dux.workArea();
            toast.x = a.x + a.width - toast.width - 12;
            toast.y = a.y + a.height - toast.height - 12;
            toast.visible = true;
            hideTimer.restart();
        });
    }

    transientParent: null
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    width: 380
    height: body.implicitHeight + 28
    visible: false

    Timer {
        id: hideTimer
        interval: toast.actionLabel ? 12000 : 6000
        onTriggered: toast.visible = false
    }

    Rectangle {
        width: toast.width
        height: toast.height
        radius: 16
        color: Theme.surfaceContainer
        border.width: 1
        border.color: toast.isError ? Theme.withAlpha(Theme.error, 0.5) : Theme.withAlpha(Theme.onSurface, 0.12)

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: containsMouse ? hideTimer.stop() : hideTimer.restart()
            onClicked: toast.visible = false
        }

        Row {
            id: body
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 12

            Image {
                width: 36
                height: 36
                source: dux.appIconUrl
                sourceSize: Qt.size(72, 72)
                smooth: true
                mipmap: true
            }
            Column {
                width: parent.width - 48
                spacing: 4
                StyledText {
                    width: parent.width
                    text: toast.heading
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                StyledText {
                    width: parent.width
                    visible: text !== ""
                    text: toast.message
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }
                StyledText {
                    visible: toast.actionLabel !== ""
                    topPadding: 2
                    text: toast.actionLabel
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: "#D97757"
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            toast.visible = false;
                            toast.actionClicked(toast.actionKey);
                        }
                    }
                }
            }
        }
    }
}
