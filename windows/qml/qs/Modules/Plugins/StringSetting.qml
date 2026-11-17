import QtQuick
import QtQuick.Controls
import qs.Common
import qs.DCommon.Widgets

Column {
    id: setting
    property string settingKey
    property string label
    property string description
    property string placeholder
    property string defaultValue: ""
    readonly property string value: dux.settings[settingKey] ?? defaultValue

    width: parent ? parent.width : 480
    spacing: 4

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
    TextField {
        width: parent.width
        text: setting.value
        placeholderText: setting.placeholder
        onEditingFinished: dux.saveSetting(setting.settingKey, text)
    }
}
