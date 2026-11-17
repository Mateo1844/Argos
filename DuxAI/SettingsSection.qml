// A titled card that groups related settings (used by DuxAISettings.qml and
// the Windows settings window). Children are stacked in a column inside it.
import QtQuick
import qs.Common
import qs.DCommon.Widgets

Rectangle {
    id: section
    property string title
    property string icon: ""
    property string subtitle: ""
    default property alias content: body.data

    width: parent ? parent.width : 480
    implicitHeight: inner.implicitHeight + 2 * Theme.spacingM
    height: implicitHeight
    radius: Theme.cornerRadius
    color: Theme.surfaceContainer

    Column {
        id: inner
        x: Theme.spacingM
        y: Theme.spacingM
        width: parent.width - 2 * Theme.spacingM
        spacing: Theme.spacingM

        Row {
            spacing: Theme.spacingS
            DIcon {
                visible: section.icon !== ""
                name: section.icon
                size: Theme.fontSizeLarge + 2
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: section.title
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                color: Theme.onSurface
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        StyledText {
            visible: section.subtitle !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            text: section.subtitle
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.onSurfaceVariant
        }

        Column {
            id: body
            width: parent.width
            spacing: Theme.spacingM + 4
        }
    }
}
