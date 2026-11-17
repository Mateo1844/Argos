import QtQuick
import QtQuick.Controls
import qs.Common
import qs.DCommon.Widgets

Column {
    id: setting
    property string settingKey
    property string label
    property string description
    property var options: []        // [{ label, value }]
    property var defaultValue
    readonly property var value: dux.settings[settingKey] ?? defaultValue

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
    ComboBox {
        width: Math.min(parent.width, 320)
        model: setting.options
        textRole: "label"
        valueRole: "value"
        currentIndex: Math.max(0, setting.options.findIndex(o => String(o.value) === String(setting.value)))
        onActivated: index => dux.saveSetting(setting.settingKey, setting.options[index].value)
    }
}
