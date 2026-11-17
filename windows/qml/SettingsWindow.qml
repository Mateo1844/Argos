// Settings window of the Windows app: shows DuxAI/DuxAISettings.qml (the
// same settings page DMS shows) plus the Windows-only options.
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import qs.Common
import qs.DCommon.Widgets

Window {
    id: settingsWindow
    objectName: "argosSettings"     // the app finds the window by this name
    property url settingsPage
    title: "Argos settings"
    width: 560
    height: 720
    color: Theme.surface

    ScrollView {
        id: scroll
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth

        Column {
            width: scroll.availableWidth
            spacing: 18

            StyledText {
                text: "Settings"
                font.pixelSize: Theme.fontSizeLarge + 6
                font.weight: Font.Bold
            }

            Loader {
                width: parent.width
                source: settingsWindow.settingsPage
            }

            StyledText {
                topPadding: 10
                text: "Windows"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
            }
            StyledText {
                width: parent.width
                wrapMode: Text.Wrap
                text: "Shortcuts, written like Win+Shift+A or Ctrl+Alt+Space. Leave empty to turn one off. Changes apply after restarting Argos (tray icon → Quit, then start it again)."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.onSurfaceVariant
            }
            Repeater {
                model: [
                    { key: "hotkeyCapture", label: "Ask about a screen region", def: "Win+Shift+A" },
                    { key: "hotkeyText", label: "Ask about selected text", def: "Win+Shift+X" },
                    { key: "hotkeyChat", label: "Open the chat", def: "" }
                ]
                Row {
                    required property var modelData
                    spacing: 12
                    StyledText {
                        width: 220
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                    }
                    TextField {
                        width: 200
                        text: dux.settings[modelData.key] ?? modelData.def
                        placeholderText: "off"
                        onEditingFinished: dux.saveSetting(modelData.key, text.trim())
                    }
                }
            }
            Row {
                spacing: 12
                StyledText {
                    width: 220
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Start with Windows"
                }
                Switch {
                    checked: dux.startWithWindows
                    onToggled: dux.setStartWithWindows(checked)
                }
            }
        }
    }
}
