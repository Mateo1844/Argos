import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "duxAi"

    StyledText {
        width: parent.width
        text: "DUX-AI"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.onSurface
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Uses the Claude Code CLI with your Claude subscription. Run `claude` once in a terminal and /login before first use."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.onSurfaceVariant
    }

    SelectionSetting {
        settingKey: "model"
        label: "Default model"
        description: "Also changeable in the chat window. Haiku is cheapest, Opus is strongest."
        options: [
            { label: "Sonnet", value: "sonnet" },
            { label: "Opus", value: "opus" },
            { label: "Haiku", value: "haiku" }
        ]
        defaultValue: "sonnet"
    }

    SelectionSetting {
        settingKey: "effort"
        label: "Default thinking level"
        description: "Higher = better answers on hard questions, but slower and uses more of your usage limit."
        options: [
            { label: "Low", value: "low" },
            { label: "Medium", value: "medium" },
            { label: "High", value: "high" },
            { label: "Extra high", value: "xhigh" },
            { label: "Max", value: "max" }
        ]
        defaultValue: "medium"
    }

    StringSetting {
        settingKey: "models"
        label: "Models in the picker"
        description: "Comma-separated Claude Code model names or aliases."
        placeholder: "sonnet,opus,haiku"
        defaultValue: "sonnet,opus,haiku"
    }

    ToggleSetting {
        settingKey: "allowWeb"
        label: "Allow web search"
        description: "Lets Claude search the web. Off by default because tool definitions cost extra tokens."
        defaultValue: false
    }

    SelectionSetting {
        settingKey: "maxImageSide"
        label: "Screenshot size limit"
        description: "Big selections are shrunk before sending (needs python3-pillow). Smaller = fewer tokens."
        options: [
            { label: "800 px", value: "800" },
            { label: "1280 px (recommended)", value: "1280" },
            { label: "1568 px (max detail)", value: "1568" },
            { label: "Don't shrink", value: "0" }
        ]
        defaultValue: "1280"
    }

    StringSetting {
        settingKey: "extraInstructions"
        label: "Extra instructions"
        description: "Added to the system prompt, e.g. \"Answer in Dutch\"."
        placeholder: "Optional"
        defaultValue: ""
    }

    SelectionSetting {
        settingKey: "pillColor"
        label: "Bar icon color"
        options: [
            { label: "Claude orange", value: "claude" },
            { label: "Theme accent", value: "theme" }
        ]
        defaultValue: "claude"
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Keyboard shortcuts (niri): add this to ~/.config/niri/config.kdl inside binds { }:\nMod+Shift+A { spawn \"dms\" \"ipc\" \"call\" \"widget\" \"openWith\" \"duxAi\" \"capture\"; }\nMod+Shift+X { spawn \"dms\" \"ipc\" \"call\" \"widget\" \"openWith\" \"duxAi\" \"text\"; }"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.onSurfaceVariant
    }
}
