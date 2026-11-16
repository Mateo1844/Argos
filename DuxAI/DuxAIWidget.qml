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
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "dux-ai"
    popoutWidth: 460
    popoutHeight: 600

    // Round colored circle with the logo inside (bar, chat header, empty
    // screen). Shows a white copy of assets/logo.svg if it exists, otherwise
    // a sparkle icon. (Inline component: no extra file for QML to find.)
    component LogoCircle: Rectangle {
        id: circle

        property real size: 26
        property color accent: "#D97757"
        property string logoPath: ""
        property bool hasLogo: false

        width: size
        height: size
        radius: size / 2
        color: accent

        Image {
            id: logo
            anchors.centerIn: parent
            width: circle.size * 0.62
            height: width
            source: circle.hasLogo ? "file://" + circle.logoPath : ""
            sourceSize: Qt.size(128, 128)
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: status === Image.Ready
        }
        DIcon {
            anchors.centerIn: parent
            visible: logo.status !== Image.Ready
            name: "auto_awesome"
            size: circle.size * 0.62
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
    readonly property bool allowWeb: pluginData.allowWeb ?? false
    readonly property int maxImageSide: parseInt(pluginData.maxImageSide || "1280")
    readonly property string extraInstructions: pluginData.extraInstructions || ""
    readonly property bool useThemeColor: pluginData.pillColor === "theme"
    readonly property color accent: useThemeColor ? Theme.primary : "#D97757"

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
    property var tokens: null           // { total, context, last: { input, cached, output } }

    function fmtTokens(n) {
        n = n || 0;
        return n < 1000 ? String(n) : (n < 100000 ? (n / 1000).toFixed(1) : Math.round(n / 1000)) + "k";
    }

    signal focusInput
    signal scrollToEnd

    ListModel {
        id: messages   // { role, text, image, quote, isError }
    }

    function setModel(value) {
        modelOverride = value;
        pluginService?.savePluginData("duxAi", "model", value);
    }

    function setEffort(value) {
        effortOverride = value;
        pluginService?.savePluginData("duxAi", "effort", value);
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

        messages.append({ role: "user", text: text, image: pendingImage, quote: pendingQuote, isError: false });
        messages.append({ role: "assistant", text: "", image: "", quote: "", isError: false });
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
        if (extraInstructions)
            cmd.push("--extra=" + extraInstructions);
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

    function stop() {
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
                messages.append({ role: m.role, text: m.text || "", image: m.image || "", quote: m.quote || "", isError: false });
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
                accent: root.accent
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

                        LogoCircle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: 48
                            accent: root.accent
                            logoPath: root.logoPath
                            hasLogo: root.hasLogo
                        }
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
                    Layout.preferredHeight: inputCol.implicitHeight + 16
                    radius: Theme.cornerRadius * 2
                    color: Theme.withAlpha(Theme.onSurface, 0.06)
                    border.width: input.activeFocus ? 1 : 0
                    border.color: Theme.withAlpha(root.accent, 0.6)

                    Column {
                        id: inputCol
                        x: 10
                        y: 8
                        width: parent.width - 20
                        spacing: 6

                        ScrollView {
                            width: parent.width
                            height: Math.min(Math.max(input.implicitHeight, 24), 140)

                            TextArea {
                                id: input
                                placeholderText: root.pendingImage || root.pendingQuote ? "Ask about your selection…" : "Ask Claude…"
                                placeholderTextColor: Theme.onSurfaceVariant
                                color: Theme.onSurface
                                font.pixelSize: root.fsBody
                                wrapMode: TextArea.Wrap
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
                            spacing: 6

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
                            DIcon {
                                visible: root.allowWeb
                                name: "travel_explore"
                                size: 16
                                color: Theme.onSurfaceVariant
                            }
                            Item {
                                Layout.fillWidth: true
                            }

                            // Discrete token counter; hover for details of the last answer.
                            StyledText {
                                visible: root.tokens !== null && root.tokens.total > 0
                                text: !root.tokens ? "" : (tokenMouse.containsMouse && root.tokens.last
                                    ? root.fmtTokens(root.tokens.last.input) + " in (" + root.fmtTokens(root.tokens.last.cached) + " cached) · " + root.fmtTokens(root.tokens.last.output) + " out"
                                    : root.fmtTokens(root.tokens.total) + " tokens")
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
