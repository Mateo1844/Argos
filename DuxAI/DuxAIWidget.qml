// DUX-AI: Claude in the DankMaterialShell top bar.
//
// This file is only UI. Everything else (talking to Claude, saving chats,
// screenshots) is done by backend/duxai.py, which we run as a process and
// which answers with one JSON object per line.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "dux-ai"
    popoutWidth: 460
    popoutHeight: 600

    // Small round icon button.
    component IconBtn: Rectangle {
        id: btn

        property string icon: ""
        property bool active: false
        property bool filled: false
        property int iconSize: 18
        property color iconColor: Theme.onSurfaceVariant
        signal clicked

        implicitWidth: 32
        implicitHeight: 32
        radius: width / 2
        color: active ? Theme.withAlpha(Theme.primary, 0.18) : (mouse.containsMouse ? Theme.withAlpha(Theme.onSurface, 0.08) : "transparent")
        opacity: enabled ? 1 : 0.4

        DIcon {
            anchors.centerIn: parent
            name: btn.icon
            size: btn.iconSize
            filled: btn.filled
            color: btn.active ? Theme.primary : btn.iconColor
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    // Rounded chip that opens a list of choices above itself (model / thinking pickers).
    component ChipMenu: Item {
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

        implicitWidth: row.implicitWidth + 16
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

    // A row with icon, label, hint and an on/off switch (quick settings).
    component SwitchRow: Rectangle {
        id: sw
        property string icon: ""
        property string label: ""
        property string hint: ""
        property bool checked: false
        signal toggled

        implicitHeight: 52
        radius: Theme.cornerRadius
        color: swMouse.containsMouse ? Theme.withAlpha(Theme.onSurface, 0.06) : "transparent"

        DIcon {
            id: swIcon
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            name: sw.icon
            size: 18
            color: sw.checked ? root.accent : Theme.onSurfaceVariant
        }
        Column {
            anchors.left: swIcon.right
            anchors.leftMargin: 10
            anchors.right: track.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            StyledText {
                text: sw.label
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.onSurface
            }
            StyledText {
                width: parent.width
                text: sw.hint
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.onSurfaceVariant
            }
        }
        Rectangle {
            id: track
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 20
            radius: 10
            color: sw.checked ? root.accent : Theme.withAlpha(Theme.onSurface, 0.2)
            Rectangle {
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: sw.checked ? parent.width - width - 3 : 3
                color: "white"
                Behavior on x {
                    NumberAnimation { duration: 120 }
                }
            }
        }
        MouseArea {
            id: swMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }
    }

    // Round colored circle with the logo inside (bar, chat header, empty
    // screen). Shows a white copy of assets/logo.svg if it exists, otherwise
    // a sparkle icon. (Inline component: no extra file for QML to find.)
    component LogoCircle: Rectangle {
        id: circle

        property real size: 26
        property color accent: "#D97757"
        property string logoPath: ""
        property bool hasLogo: false
        property real logoScale: 0.62

        width: size
        height: size
        radius: size / 2
        color: accent

        Image {
            id: logo
            anchors.centerIn: parent
            width: circle.size * circle.logoScale
            height: width
            source: circle.hasLogo ? "file://" + circle.logoPath : ""
            // Render the SVG at (about) the size it is shown, so it stays sharp:
            // shrinking a big render down to ~16 px makes it look pixelated.
            sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            visible: status === Image.Ready
        }
        DIcon {
            anchors.centerIn: parent
            visible: logo.status !== Image.Ready
            name: "auto_awesome"
            size: circle.size * circle.logoScale
            filled: true
            color: "white"
        }
    }

    // ------------------------------------------------------------ settings --
    readonly property string backend: decodeURIComponent(String(Qt.resolvedUrl("backend/duxai.py")).replace("file://", ""))
    property string modelOverride: ""
    property string effortOverride: ""
    readonly property string model: modelOverride || pluginData.model || "sonnet"
    readonly property string effort: effortOverride || pluginData.effort || "medium"
    // Quick settings (gear in the chat header); also in the plugin settings page.
    property bool allowWeb: pluginData.allowWeb ?? false
    property bool screenViewer: pluginData.screenViewer ?? true   // Claude may look at the screen when needed

    function setQuick(key, value) {
        if (key === "allowWeb")
            allowWeb = value;
        else if (key === "screenViewer")
            screenViewer = value;
        pluginService?.savePluginData("duxAi", key, value);
    }
    readonly property int maxImageSide: parseInt(pluginData.maxImageSide || "1280")
    readonly property string extraInstructions: pluginData.extraInstructions || ""
    readonly property bool includeWindow: pluginData.includeWindow ?? true
    // Agent mode (Claude may use your computer, asks before changes)
    readonly property string permLevel: pluginData.permLevel || "ask_changes"
    readonly property string trustedFolders: pluginData.trustedFolders || ""
    readonly property string askFolders: pluginData.askFolders || ""
    readonly property string denyFolders: pluginData.denyFolders || ""
    readonly property bool useThemeColor: pluginData.pillColor === "theme"
    readonly property color accent: useThemeColor ? Theme.primary : "#D97757"
    readonly property bool pillTransparent: pluginData.pillColor === "transparent"
    readonly property bool showBorder: pluginData.showBorder ?? true

    readonly property var modelOptions: (pluginData.models || "sonnet,opus,haiku").split(",").map(s => s.trim()).filter(s => s.length > 0).map(s => ({
                value: s,
                label: s.charAt(0).toUpperCase() + s.slice(1)
            }))
    readonly property var effortOptions: [
        { value: "low", label: "Low" },
        { value: "medium", label: "Medium" },
        { value: "high", label: "High" },
        { value: "xhigh", label: "Extra high" },
        { value: "max", label: "Max" }
    ]

    // One step bigger than the DMS defaults.
    readonly property real fsSmall: Theme.fontSizeMedium
    readonly property real fsBody: Theme.fontSizeLarge
    readonly property real fsTitle: Theme.fontSizeLarge + 3

    // --------------------------------------------------------------- state --
    property string view: "chat"        // "chat" or "history"
    property string chatId: ""          // "" = new, unsaved chat
    property string chatTitle: ""
    property string pendingImage: ""    // screenshot waiting to be sent
    property string pendingQuote: ""    // selected text waiting to be sent
    property bool busy: false
    property bool gotFinal: false
    property string status: ""
    property var historyItems: []
    property string storageText: ""
    property bool confirmDeleteAll: false
    property bool quickSettingsOpen: false
    property bool agentMode: pluginData.agentDefault ?? false
    property var permission: null       // { id, summary, reason } while Claude waits for Allow/Deny
    property string windowApp: ""       // active window when the chat was opened
    property string windowTitle: ""
    readonly property string windowText: windowApp ? windowApp + (windowTitle ? " — " + windowTitle : "") : ""
    property var tokens: null           // { total, context, last: { input, cached, output } }

    function fmtTokens(n) {
        n = n || 0;
        return n < 1000 ? String(n) : (n < 100000 ? (n / 1000).toFixed(1) : Math.round(n / 1000)) + "k";
    }

    signal focusInput
    signal scrollToEnd

    ListModel {
        id: messages   // { role, text, image, quote, window, steps, isError }
    }

    function setModel(value) {
        modelOverride = value;
        pluginService?.savePluginData("duxAi", "model", value);
    }

    function setEffort(value) {
        effortOverride = value;
        pluginService?.savePluginData("duxAi", "effort", value);
    }

    // ------------------------------------------------------- active window --
    // Which app/window you were looking at, so "this folder" etc. makes sense.
    // We remember the last real window continuously: once the chat is open it
    // has keyboard focus itself, so asking the compositor *then* returns nothing.
    property var lastToplevel: null
    readonly property Toplevel activeToplevel: ToplevelManager.activeToplevel
    onActiveToplevelChanged: {
        if (activeToplevel && (activeToplevel.appId || activeToplevel.title))
            lastToplevel = activeToplevel;
    }

    function prettyApp(appId) {
        // "org.kde.dolphin" -> "Dolphin"
        const last = (appId || "").split(".").pop().replace(/-/g, " ").trim();
        return last ? last.charAt(0).toUpperCase() + last.slice(1) : "";
    }

    function fetchWindow() {
        if (!includeWindow || busy)
            return;
        if (lastToplevel && (lastToplevel.appId || lastToplevel.title)) {
            const app = prettyApp(lastToplevel.appId);
            const title = lastToplevel.title || "";
            windowApp = app;
            windowTitle = title;
            return;
        }
        // Fallback: ask the compositor (niri / Hyprland) via the backend.
        Proc.runCommand("duxAi.window", ["python3", backend, "window"], out => {
            const ev = lastJson(out);
            if (ev?.type !== "window")
                return;
            windowApp = ev.app;
            windowTitle = ev.title;
        });
    }

    onInteractionActiveChanged: {
        if (interactionActive)
            fetchWindow();
    }

    // ------------------------------------------------------- popout control --
    function openPopout() {
        if (!root.interactionActive)
            root.triggerPopout();
        focusTimer.restart();
    }

    // Called by `dms ipc call widget openWith duxAi <mode>` (keyboard shortcut).
    function openWithMode(mode) {
        if (mode === "capture")
            startCapture();
        else if (mode === "text")
            grabSelection();
        else
            openPopout();
    }

    Timer {
        id: focusTimer
        interval: 80
        onTriggered: root.focusInput()
    }

    // ------------------------------------------------------------- capture --
    function startCapture() {
        fetchWindow();
        root.closePopout();          // get the window out of the way first
        captureTimer.restart();
    }

    Timer {
        id: captureTimer
        interval: 300                // let the popout finish closing
        onTriggered: Proc.runCommand("duxAi.capture", ["python3", root.backend, "capture"], (out, code) => {
            const ev = root.lastJson(out);
            if (ev?.type === "captured") {
                root.pendingImage = ev.path;
                root.view = "chat";
            } else if (ev?.type === "error") {
                ToastService.showError("DUX-AI: " + ev.message);
            }
            root.openPopout();
        })
    }

    // Text highlighted anywhere on screen (Wayland primary selection).
    function grabSelection() {
        fetchWindow();
        Proc.runCommand("duxAi.selection", ["python3", root.backend, "selection"], (out, code) => {
            const ev = root.lastJson(out);
            if (ev?.type === "selection") {
                root.pendingQuote = ev.text;
                root.view = "chat";
            } else if (ev?.type === "error") {
                ToastService.showError("DUX-AI: " + ev.message);
            }
            root.openPopout();
        });
    }

    // ---------------------------------------------------------------- chat --
    function shortTitle(text) {
        text = text.replace(/\s+/g, " ").trim();
        return text.length > 48 ? text.slice(0, 48) + "…" : (text || "Screenshot");
    }

    function send(text) {
        text = text.trim();
        if (busy || (!text && !pendingImage && !pendingQuote))
            return false;

        const win = includeWindow ? windowText : "";   // sent along invisibly
        messages.append({ role: "user", text: text, image: pendingImage, quote: pendingQuote, window: win, steps: "", isError: false });
        messages.append({ role: "assistant", text: "", image: "", quote: "", window: "", steps: "", isError: false });
        if (!chatId)
            chatTitle = shortTitle(text || pendingQuote);

        const cmd = ["python3", backend, "ask", "--model=" + model, "--effort=" + effort,
                     "--max-image-side=" + maxImageSide];
        if (chatId)
            cmd.push("--chat=" + chatId);
        if (pendingImage)
            cmd.push("--image=" + pendingImage);
        if (pendingQuote)
            cmd.push("--quote=" + pendingQuote);
        if (allowWeb)
            cmd.push("--web");
        if (screenViewer)
            cmd.push("--screen");
        if (extraInstructions)
            cmd.push("--extra=" + extraInstructions);
        if (win)
            cmd.push("--window=" + win);
        if (agentMode)
            cmd.push("--agent", "--perm=" + permLevel, "--trusted=" + trustedFolders,
                     "--ask-dirs=" + askFolders, "--deny-dirs=" + denyFolders);
        cmd.push("--", text);

        pendingImage = "";
        pendingQuote = "";
        busy = true;
        gotFinal = false;
        status = "";
        askProc.command = cmd;
        askProc.running = true;
        scrollToEnd();
        return true;
    }

    // Allow / Deny buttons -> backend stdin -> Claude Code.
    function answerPermission(allow) {
        if (!permission)
            return;
        askProc.write(JSON.stringify({ id: permission.id, allow: allow }) + "\n");
        permission = null;
    }

    function stop() {
        permission = null;
        if (askProc.running)
            askProc.running = false;   // SIGTERM: backend stops claude and keeps the partial answer
    }

    function setLastText(text, isError) {
        const last = messages.count - 1;
        if (last < 0)
            return;
        messages.setProperty(last, "text", text);
        messages.setProperty(last, "isError", !!isError);
    }

    function handleEvent(line) {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        const last = messages.count - 1;
        switch (ev.type) {
        case "start":
            chatId = ev.chat;
            break;
        case "text":
            if (last >= 0)
                messages.setProperty(last, "text", messages.get(last).text + ev.text);
            status = "";
            scrollToEnd();
            break;
        case "status":
            status = ev.text;
            break;
        case "step":
            if (last >= 0) {
                const steps = messages.get(last).steps;
                messages.setProperty(last, "steps", steps ? steps + "\n" + ev.text : ev.text);
            }
            status = ev.text;
            scrollToEnd();
            break;
        case "permission":
            permission = { id: ev.id, summary: ev.summary, reason: ev.reason || "" };
            scrollToEnd();
            break;
        case "permission_cancel":
            if (permission && permission.id === ev.id)
                permission = null;
            break;
        case "done":
            gotFinal = true;
            if (ev.tokens)
                tokens = ev.tokens;
            setLastText(ev.text, false);
            scrollToEnd();
            break;
        case "error":
            gotFinal = true;
            setLastText(ev.message, true);
            scrollToEnd();
            break;
        }
    }

    Process {
        id: askProc
        stdinEnabled: true             // used to send Allow/Deny answers
        stdout: SplitParser {
            onRead: line => root.handleEvent(line)
        }
        onExited: (code, exitStatus) => {
            if (!root.gotFinal) {
                // Killed by the stop button (or crashed) before sending "done".
                const last = messages.count - 1;
                const partial = last >= 0 ? messages.get(last).text : "";
                root.setLastText(partial ? partial + "\n\n*(stopped)*" : "Stopped (backend exit code " + code + ").", !partial);
            }
            root.busy = false;
            root.permission = null;
            root.status = "";
            root.refreshHistory();
        }
    }

    function newChat() {
        if (busy)
            return;
        chatId = "";
        chatTitle = "";
        tokens = null;
        messages.clear();
        view = "chat";
        focusInput();
    }

    // ------------------------------------------------------------ history --
    function lastJson(out) {
        const lines = (out || "").trim().split("\n");
        try {
            return JSON.parse(lines[lines.length - 1]);
        } catch (e) {
            return null;
        }
    }

    function applyList(out) {
        const ev = lastJson(out);
        if (ev?.type === "list") {
            historyItems = ev.chats;
            storageText = ev.size;
        }
    }

    function refreshHistory() {
        Proc.runCommand("duxAi.list", ["python3", backend, "list"], out => applyList(out));
    }

    function openChat(id) {
        if (busy)
            return;
        Proc.runCommand("duxAi.load", ["python3", backend, "load", id], out => {
            const ev = lastJson(out);
            if (ev?.type !== "chat")
                return;
            messages.clear();
            for (const m of ev.chat.messages)
                messages.append({ role: m.role, text: m.text || "", image: m.image || "", quote: m.quote || "", window: m.window || "", steps: (m.steps || []).join("\n"), isError: false });
            chatId = ev.chat.id;
            chatTitle = ev.chat.title;
            tokens = ev.tokens || null;
            view = "chat";
            scrollToEnd();
        });
    }

    function deleteChat(id) {
        if (id === chatId)
            newChat();
        Proc.runCommand("duxAi.delete", ["python3", backend, "delete", id], out => applyList(out));
    }

    function deleteAll() {
        newChat();
        confirmDeleteAll = false;
        Proc.runCommand("duxAi.delete", ["python3", backend, "delete", "all"], out => applyList(out));
    }

    // Optional custom logo: put an SVG at DuxAI/assets/logo.svg.
    // The backend makes a white copy so it is visible on the colored circle.
    property string logoPath: ""
    readonly property bool hasLogo: logoPath !== ""

    Component.onCompleted: {
        if (activeToplevel && (activeToplevel.appId || activeToplevel.title))
            lastToplevel = activeToplevel;
        refreshHistory();
        Proc.runCommand("duxAi.logo", ["python3", backend, "logo"], out => {
            const ev = lastJson(out);
            logoPath = ev?.path || "";
        });
    }

    // ------------------------------------------------------------ bar pill --
    // Just a round circle. Drop an SVG at assets/logo.svg to use your own
    // logo; otherwise a sparkle icon is shown.
    Component {
        id: pillComponent

        Item {
            implicitWidth: root.iconSize + 6
            implicitHeight: root.iconSize + 6

            LogoCircle {
                id: circle
                anchors.centerIn: parent
                size: parent.implicitWidth
                accent: root.pillTransparent ? "transparent" : root.accent
                logoScale: root.pillTransparent ? 0.9 : 0.62
                logoPath: root.logoPath
                hasLogo: root.hasLogo

                // Gentle pulse while Claude is answering.
                SequentialAnimation on opacity {
                    running: root.busy
                    loops: Animation.Infinite
                    onStopped: circle.opacity = 1
                    NumberAnimation { to: 0.45; duration: 600; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

    horizontalBarPill: pillComponent
    verticalBarPill: pillComponent
    pillRightClickAction: () => root.startCapture()   // right-click = ask about screen

    // -------------------------------------------------------------- popout --
    popoutContent: Component {
        Item {
            id: win
            implicitHeight: root.popoutHeight - 40
            width: parent ? parent.width : root.popoutWidth

            Connections {
                target: root
                function onFocusInput() {
                    if (root.view === "chat")
                        input.forceActiveFocus();
                }
                function onScrollToEnd() {
                    Qt.callLater(() => chatList.positionViewAtEnd());
                }
                function onInteractionActiveChanged() {
                    if (root.interactionActive)
                        focusTimer.restart();
                }
            }
            Component.onCompleted: focusTimer.restart()

            // Thin outline along the edge of the popout (Settings: "Window border").
            Rectangle {
                visible: root.showBorder
                anchors.fill: parent
                anchors.margins: -PopoutMetrics.contentPadding
                radius: Theme.windowRadius
                color: "transparent"
                border.width: 1
                border.color: Theme.withAlpha(root.accent, 0.45)
                z: 100
            }

            // ---- quick settings panel (gear button) ----
            Rectangle {
                visible: root.quickSettingsOpen
                z: 200
                anchors.right: parent.right
                y: 40
                width: 280
                height: quickCol.implicitHeight + 16
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.width: 1
                border.color: Theme.outlineVariant

                Column {
                    id: quickCol
                    x: 8
                    y: 8
                    width: parent.width - 16
                    spacing: 2

                    SwitchRow {
                        width: parent.width
                        icon: "travel_explore"
                        label: "Web search"
                        hint: "Claude may search the internet"
                        checked: root.allowWeb
                        onToggled: root.setQuick("allowWeb", !root.allowWeb)
                    }
                    SwitchRow {
                        width: parent.width
                        icon: "visibility"
                        label: "Screen viewer"
                        hint: "Claude may look at your screen when you ask about it"
                        checked: root.screenViewer
                        onToggled: root.setQuick("screenViewer", !root.screenViewer)
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: Theme.spacingS

                // ---- header ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    LogoCircle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        size: 26
                        accent: root.accent
                        logoPath: root.logoPath
                        hasLogo: root.hasLogo
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.spacingS
                        text: root.view === "history" ? "Chats" : (root.chatTitle || "Claude")
                        font.pixelSize: root.fsTitle
                        font.weight: Font.Medium
                        color: Theme.onSurface
                        elide: Text.ElideRight
                    }
                    IconBtn {
                        icon: "screenshot_region"
                        onClicked: root.startCapture()
                    }
                    IconBtn {
                        icon: "format_quote"
                        filled: true
                        onClicked: root.grabSelection()
                    }
                    IconBtn {
                        icon: "edit_square"
                        enabled: !root.busy
                        onClicked: root.newChat()
                    }
                    IconBtn {
                        icon: "history"
                        active: root.view === "history"
                        onClicked: {
                            root.view = root.view === "history" ? "chat" : "history";
                            root.confirmDeleteAll = false;
                            if (root.view === "history")
                                root.refreshHistory();
                        }
                    }
                    IconBtn {
                        icon: "settings"
                        active: root.quickSettingsOpen
                        onClicked: root.quickSettingsOpen = !root.quickSettingsOpen
                    }
                }

                // ---- chat view ----
                Item {
                    visible: root.view === "chat"
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Empty state
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingS
                        visible: messages.count === 0

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "How can I help?"
                            font.pixelSize: root.fsTitle
                            color: Theme.onSurface
                        }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: win.width - 60
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: "Tip: right-click the bar icon or press Mod+Shift+A to ask about part of your screen. Highlight text and press Mod+Shift+X to ask about it."
                            font.pixelSize: root.fsSmall
                            color: Theme.onSurfaceVariant
                        }
                    }

                    ListView {
                        id: chatList
                        anchors.fill: parent
                        clip: true
                        spacing: Theme.spacingM
                        model: messages
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {}

                        delegate: Item {
                            id: msg
                            required property int index
                            required property string role
                            required property string text
                            required property string image
                            required property string quote
                            required property string window
                            required property string steps
                            required property bool isError
                            readonly property bool isUser: role === "user"
                            readonly property bool isLast: index === messages.count - 1

                            width: chatList.width - 8
                            height: bubble.height + (copyRow.visible ? copyRow.height : 0)

                            Rectangle {
                                id: bubble
                                anchors.right: msg.isUser ? parent.right : undefined
                                width: msg.isUser ? Math.min(parent.width * 0.85, Math.max(body.implicitWidth, msg.quote !== "" ? 240 : (msg.image !== "" ? 130 : 0)) + 24) : parent.width
                                height: content.implicitHeight + (msg.isUser ? 16 : 4)
                                radius: Theme.cornerRadius * 1.5
                                color: msg.isUser ? Theme.withAlpha(root.accent, 0.16) : "transparent"

                                Column {
                                    id: content
                                    x: msg.isUser ? 12 : 2
                                    y: msg.isUser ? 8 : 2
                                    width: bubble.width - (msg.isUser ? 24 : 4)
                                    spacing: 6

                                    // Compact screenshot chip (click to open full size)
                                    Rectangle {
                                        id: shot
                                        visible: msg.image !== ""
                                        width: shotRow.implicitWidth + 12
                                        height: visible ? 32 : 0
                                        radius: Theme.cornerRadius
                                        color: shotMouse.containsMouse ? Theme.withAlpha(Theme.onSurface, 0.12) : Theme.withAlpha(Theme.onSurface, 0.06)

                                        Row {
                                            id: shotRow
                                            x: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 8
                                            Image {
                                                width: 36
                                                height: 24
                                                source: msg.image ? "file://" + msg.image : ""
                                                sourceSize: Qt.size(72, 48)
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                            }
                                            StyledText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Screenshot"
                                                font.pixelSize: root.fsSmall
                                                color: Theme.onSurfaceVariant
                                            }
                                        }
                                        MouseArea {
                                            id: shotMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Qt.openUrlExternally("file://" + msg.image)
                                        }
                                    }

                                    // Selected text the question was about
                                    Rectangle {
                                        visible: msg.quote !== ""
                                        width: content.width
                                        height: visible ? quoteText.implicitHeight + 12 : 0
                                        radius: Theme.cornerRadius
                                        color: Theme.withAlpha(Theme.onSurface, 0.06)
                                        Rectangle {
                                            width: 3
                                            height: parent.height - 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: 6
                                            radius: 2
                                            color: root.accent
                                        }
                                        StyledText {
                                            id: quoteText
                                            x: 16
                                            y: 6
                                            width: parent.width - 24
                                            text: msg.quote
                                            maximumLineCount: 4
                                            elide: Text.ElideRight
                                            wrapMode: Text.Wrap
                                            font.italic: true
                                            font.pixelSize: root.fsSmall
                                            color: Theme.onSurfaceVariant
                                        }
                                    }

                                    // Agent mode: what Claude did ("Read ~/x", "Run: ls")
                                    Column {
                                        visible: !msg.isUser && msg.steps !== ""
                                        width: content.width
                                        spacing: 2
                                        Repeater {
                                            model: msg.steps ? msg.steps.split("\n") : []
                                            Row {
                                                required property string modelData
                                                width: content.width
                                                spacing: 6
                                                DIcon {
                                                    name: "subdirectory_arrow_right"
                                                    size: 14
                                                    color: Theme.withAlpha(Theme.onSurfaceVariant, 0.8)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                StyledText {
                                                    width: parent.width - 20
                                                    text: modelData
                                                    elide: Text.ElideRight
                                                    font.family: "monospace"
                                                    font.pixelSize: root.fsSmall - 1
                                                    color: Theme.withAlpha(Theme.onSurfaceVariant, 0.8)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                        }
                                    }

                                    // Streaming placeholder
                                    Row {
                                        visible: !msg.isUser && msg.text === "" && msg.isLast && root.busy
                                        spacing: 8
                                        DSpinner {
                                            size: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        StyledText {
                                            text: root.status || "Thinking…"
                                            font.pixelSize: root.fsSmall
                                            color: Theme.onSurfaceVariant
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    TextEdit {
                                        id: body
                                        visible: msg.text !== ""
                                        width: msg.isUser ? Math.min(implicitWidth, content.width) : content.width
                                        text: msg.text
                                        textFormat: msg.isUser ? TextEdit.PlainText : TextEdit.MarkdownText
                                        wrapMode: TextEdit.Wrap
                                        readOnly: true
                                        selectByMouse: true
                                        color: msg.isError ? Theme.error : Theme.onSurface
                                        selectionColor: Theme.withAlpha(Theme.primary, 0.35)
                                        font.pixelSize: root.fsBody
                                        onLinkActivated: link => Qt.openUrlExternally(link)
                                    }
                                }
                            }

                            // Copy button under finished assistant answers
                            Row {
                                id: copyRow
                                anchors.top: bubble.bottom
                                visible: !msg.isUser && !msg.isError && msg.text !== "" && !(msg.isLast && root.busy)
                                height: 26
                                IconBtn {
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    iconSize: 15
                                    icon: "content_copy"
                                    onClicked: {
                                        Quickshell.execDetached(["dms", "cl", "copy", msg.text]);
                                        ToastService.showInfo("Copied answer");
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- history view ----
                Item {
                    visible: root.view === "history"
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    StyledText {
                        anchors.centerIn: parent
                        visible: root.historyItems.length === 0
                        text: "No saved chats yet"
                        color: Theme.onSurfaceVariant
                    }

                    ListView {
                        anchors.fill: parent
                        anchors.bottomMargin: footer.height + Theme.spacingS
                        clip: true
                        spacing: 4
                        model: root.historyItems
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {}

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            width: ListView.view.width - 8
                            height: 52
                            radius: Theme.cornerRadius
                            color: rowMouse.containsMouse ? Theme.withAlpha(Theme.onSurface, 0.07) : (modelData.id === root.chatId ? Theme.withAlpha(root.accent, 0.12) : "transparent")

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openChat(row.modelData.id)
                            }
                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.right: del.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                StyledText {
                                    width: parent.width
                                    text: row.modelData.title
                                    elide: Text.ElideRight
                                    color: Theme.onSurface
                                    font.pixelSize: root.fsBody
                                }
                                StyledText {
                                    text: Qt.formatDateTime(new Date(row.modelData.updated * 1000), "d MMM yyyy, HH:mm") + "  ·  " + row.modelData.model + "  ·  " + row.modelData.count + " messages" + (row.modelData.tokens ? "  ·  " + root.fmtTokens(row.modelData.tokens) + " tokens" : "")
                                    color: Theme.onSurfaceVariant
                                    font.pixelSize: root.fsSmall
                                }
                            }
                            IconBtn {
                                id: del
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "delete"
                                iconColor: rowMouse.containsMouse ? Theme.error : Theme.withAlpha(Theme.onSurfaceVariant, 0.6)
                                onClicked: root.deleteChat(row.modelData.id)
                            }
                        }
                    }

                    // Discrete storage indicator + delete all
                    RowLayout {
                        id: footer
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 30

                        DIcon {
                            name: "storage"
                            size: 14
                            color: Theme.onSurfaceVariant
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: "Saved chats use " + (root.storageText || "0 B")
                            font.pixelSize: root.fsSmall
                            color: Theme.onSurfaceVariant
                        }
                        StyledText {
                            visible: root.historyItems.length > 0
                            text: root.confirmDeleteAll ? "Click again to delete all" : "Delete all"
                            font.pixelSize: root.fsSmall
                            color: Theme.error
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.confirmDeleteAll ? root.deleteAll() : root.confirmDeleteAll = true
                            }
                        }
                    }
                }

                // ---- Allow / Deny card (agent mode) ----
                Rectangle {
                    visible: root.view === "chat" && root.permission !== null
                    Layout.fillWidth: true
                    Layout.preferredHeight: permCol.implicitHeight + 20
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(root.accent, 0.10)
                    border.width: 1
                    border.color: Theme.withAlpha(root.accent, 0.55)

                    Column {
                        id: permCol
                        x: 12
                        y: 10
                        width: parent.width - 24
                        spacing: 8

                        Row {
                            spacing: 6
                            DIcon {
                                name: "shield_question"
                                size: 18
                                color: root.accent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                text: "Claude wants to:"
                                font.pixelSize: root.fsSmall
                                font.weight: Font.Medium
                                color: Theme.onSurface
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        StyledText {
                            width: parent.width
                            text: root.permission ? root.permission.summary : ""
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 6
                            elide: Text.ElideRight
                            font.family: "monospace"
                            font.pixelSize: root.fsSmall
                            color: Theme.onSurface
                        }
                        StyledText {
                            visible: text !== ""
                            width: parent.width
                            text: root.permission ? root.permission.reason : ""
                            wrapMode: Text.Wrap
                            font.pixelSize: root.fsSmall - 1
                            color: Theme.onSurfaceVariant
                        }
                        Row {
                            anchors.right: parent.right
                            spacing: 8
                            Rectangle {
                                width: denyText.implicitWidth + 28
                                height: 30
                                radius: 15
                                color: denyMouse.containsMouse ? Theme.withAlpha(Theme.onSurface, 0.14) : Theme.withAlpha(Theme.onSurface, 0.07)
                                StyledText {
                                    id: denyText
                                    anchors.centerIn: parent
                                    text: "Deny"
                                    font.pixelSize: root.fsSmall
                                    color: Theme.onSurface
                                }
                                MouseArea {
                                    id: denyMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.answerPermission(false)
                                }
                            }
                            Rectangle {
                                width: allowText.implicitWidth + 28
                                height: 30
                                radius: 15
                                color: allowMouse.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent
                                StyledText {
                                    id: allowText
                                    anchors.centerIn: parent
                                    text: "Allow"
                                    font.pixelSize: root.fsSmall
                                    font.weight: Font.Medium
                                    color: "white"
                                }
                                MouseArea {
                                    id: allowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.answerPermission(true)
                                }
                            }
                        }
                    }
                }

                // ---- attached screenshot ----
                Rectangle {
                    visible: root.view === "chat" && root.pendingImage !== ""
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.onSurface, 0.05)

                    Image {
                        id: thumb
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 28
                        sourceSize: Qt.size(80, 56)
                        fillMode: Image.PreserveAspectCrop
                        source: root.pendingImage ? "file://" + root.pendingImage : ""
                        asynchronous: true
                    }
                    StyledText {
                        anchors.left: thumb.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Screenshot attached"
                        font.pixelSize: root.fsSmall
                        color: Theme.onSurfaceVariant
                    }
                    IconBtn {
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "close"
                        onClicked: root.pendingImage = ""
                    }
                }

                // ---- attached text ----
                Rectangle {
                    visible: root.view === "chat" && root.pendingQuote !== ""
                    Layout.fillWidth: true
                    height: 56
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.onSurface, 0.05)

                    DIcon {
                        id: quoteIcon
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        name: "format_quote"
                        size: 22
                        filled: true
                        color: root.accent
                    }
                    StyledText {
                        anchors.left: quoteIcon.right
                        anchors.leftMargin: 10
                        anchors.right: quoteClose.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.pendingQuote.replace(/\s+/g, " ")
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        font.italic: true
                        font.pixelSize: root.fsSmall
                        color: Theme.onSurfaceVariant
                    }
                    IconBtn {
                        id: quoteClose
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "close"
                        onClicked: root.pendingQuote = ""
                    }
                }

                // ---- input box ----
                Rectangle {
                    visible: root.view === "chat"
                    Layout.fillWidth: true
                    Layout.preferredHeight: inputCol.implicitHeight + 24   // 14 top + 10 bottom (= side margin)
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.onSurface, 0.06)
                    //border.width: input.activeFocus ? 1 : 0
                    //border.color: Theme.withAlpha(root.accent, 0.6)

                    Column {
                        id: inputCol
                        x: 10
                        y: 14
                        width: parent.width - 20
                        spacing: 6

                        ScrollView {
                            width: parent.width
                            height: Math.min(Math.max(input.implicitHeight, 24), 140)

                            TextArea {
                                id: input
                                placeholderText: root.pendingImage || root.pendingQuote ? "Ask about your selection…" : (root.agentMode ? "Ask Claude to do something on your PC…" : "Ask Claude…")
                                placeholderTextColor: Theme.onSurfaceVariant
                                color: Theme.onSurface
                                                                cursorDelegate: Rectangle {
                                    id: cursor
                                    property bool blinkOn: true
                                    width: 2
                                    color: Theme.onSurface
                                    visible: input.cursorVisible && blinkOn

                                    // Standard on/off blink at your system's blink speed
                                    Timer {
                                        id: blinkTimer
                                        running: input.activeFocus && Qt.styleHints.cursorFlashTime > 0
                                        repeat: true
                                        interval: Qt.styleHints.cursorFlashTime / 2
                                        onTriggered: cursor.blinkOn = !cursor.blinkOn
                                    }
                                    // Stay visible while you type or move the cursor
                                    Connections {
                                        target: input
                                        function onCursorPositionChanged() {
                                            cursor.blinkOn = true;
                                            blinkTimer.restart();
                                        }
                                    }
                                }
                                font.pixelSize: root.fsBody
                                background: null
                                padding: 0
                                selectByMouse: true

                                // Enter = send, Shift+Enter = new line
                                Keys.onPressed: event => {
                                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                                        if (root.send(input.text))
                                            input.text = "";
                                        event.accepted = true;
                                    }
                                }
                            }
                        }

                        RowLayout {
                            width: parent.width
                            spacing: 4

                            ChipMenu {
                                icon: "neurology"
                                options: root.modelOptions
                                current: root.model
                                onPicked: value => root.setModel(value)
                            }
                            ChipMenu {
                                icon: "psychology"
                                options: root.effortOptions
                                current: root.effort
                                onPicked: value => root.setEffort(value)
                            }

                            // Agent mode toggle: Claude may use your computer (asks first)
                            Rectangle {
                                Layout.preferredWidth: agentRow.implicitWidth + 16
                                Layout.preferredHeight: 30
                                radius: 15
                                color: root.agentMode ? Theme.withAlpha(root.accent, 0.22) : (agentMouse.containsMouse ? Theme.withAlpha(Theme.onSurface, 0.12) : Theme.withAlpha(Theme.onSurface, 0.06))
                                border.width: root.agentMode ? 1 : 0
                                border.color: Theme.withAlpha(root.accent, 0.6)
                                Row {
                                    id: agentRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    DIcon {
                                        name: "smart_toy"
                                        size: 14
                                        filled: root.agentMode
                                        color: root.agentMode ? root.accent : Theme.onSurfaceVariant
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    StyledText {
                                        text: "Agent"
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.onSurface
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                MouseArea {
                                    id: agentMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !root.busy
                                    onClicked: root.agentMode = !root.agentMode
                                }
                            }
                            Item {
                                Layout.fillWidth: true
                            }

                            // Discrete token counter; hover for details of the last answer.
                            StyledText {
                                visible: root.tokens !== null && root.tokens.total > 0
                                text: !root.tokens ? "" : (tokenMouse.containsMouse && root.tokens.last
                                    ? root.fmtTokens(root.tokens.last.input) + " in (" + root.fmtTokens(root.tokens.last.cached) + " cached) · " + root.fmtTokens(root.tokens.last.output) + " out"
                                    : root.fmtTokens(root.tokens.total) + " tok")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.withAlpha(Theme.onSurfaceVariant, 0.75)
                                MouseArea {
                                    id: tokenMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }

                            // Send / stop
                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: 16
                                readonly property bool canSend: input.text.trim() !== "" || root.pendingImage !== "" || root.pendingQuote !== ""
                                color: root.busy ? Theme.withAlpha(Theme.onSurface, 0.12) : (canSend ? root.accent : Theme.withAlpha(Theme.onSurface, 0.08))
                                DIcon {
                                    anchors.centerIn: parent
                                    name: root.busy ? "stop" : "arrow_upward"
                                    size: 18
                                    filled: true
                                    color: root.busy ? Theme.onSurface : (parent.canSend ? "white" : Theme.onSurfaceVariant)
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.busy)
                                            root.stop();
                                        else if (root.send(input.text))
                                            input.text = "";
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
