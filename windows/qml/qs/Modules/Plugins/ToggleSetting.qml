import QtQuick
import QtQuick.Controls
import qs.Common
import qs.DCommon.Widgets

Item {
    id: setting
    property string settingKey
    property string label
    property string description
    property bool defaultValue: false
    readonly property bool value: dux.settings[settingKey] ?? defaultValue

    width: parent ? parent.width : 480
    implicitHeight: Math.max(texts.implicitHeight, toggle.implicitHeight)

    Column {
        id: texts
        anchors.left: parent.left
        anchors.right: toggle.left
        anchors.rightMargin: 12
        spacing: 2
        StyledText {
            width: parent.width
            text: setting.label
            wrapMode: Text.Wrap
        }
        StyledText {
            visible: text !== ""
            width: parent.width
            text: setting.description
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.onSurfaceVariant
        }
    }
    Switch {
        id: toggle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        checked: setting.value
        onToggled: dux.saveSetting(setting.settingKey, checked)
    }
}
