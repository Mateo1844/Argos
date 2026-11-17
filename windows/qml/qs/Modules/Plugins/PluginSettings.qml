// Windows stand-in: the settings page is a simple column (shown in SettingsWindow.qml).
import QtQuick

Column {
    property string pluginId: "duxAi"
    readonly property string hostPlatform: "windows"
    width: parent ? parent.width : 480
    spacing: 14
}
