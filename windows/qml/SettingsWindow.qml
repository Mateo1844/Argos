// Settings window of the Windows app: shows DuxAI/DuxAISettings.qml (the
// same settings page DMS shows) plus the Windows-only options.
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import qs.Common
import qs.DCommon.Widgets
import "../../DuxAI"     // SettingsSection

Window {
    id: settingsWindow
    objectName: "argosSettings"     // the app finds the window by this name
    property url settingsPage
    title: "Argos settings"
    width: 580
    height: 760
    color: Theme.surface

    ScrollView {
        id: scroll
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth

        Column {
            width: scroll.availableWidth - 14     // room for the scrollbar
            spacing: 14

            Loader {
                width: parent.width
                source: settingsWindow.settingsPage
            }

            SettingsSection {
                title: "Windows"
                icon: "window"

                Row {
                    width: parent.width
                    spacing: 12
                    StyledText {
                        width: parent.width - startSwitch.width - 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Start with Windows"
                    }
                    Switch {
                        id: startSwitch
                        checked: dux.startWithWindows
                        onToggled: dux.setStartWithWindows(checked)
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8

                    StyledText {
                        text: "Keyboard shortcuts"
                    }
                    StyledText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "Written like Win+Shift+A or Ctrl+Alt+Space. Leave empty to turn one off. Changes apply after restarting Argos (tray icon → Quit, then start it again)."
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
                                color: Theme.onSurfaceVariant
                            }
                            TextField {
                                width: 200
                                text: dux.settings[modelData.key] ?? modelData.def
                                placeholderText: "off"
                                onEditingFinished: dux.saveSetting(modelData.key, text.trim())
                            }
                        }
                    }
                }
            }
        }
    }
}
