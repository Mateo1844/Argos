// Argos: Claude in the DankMaterialShell top bar.
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

    // The look of the floating bubble: logo circle with a soft shadow.
    component BubbleFace: Item {
        id: face
        property bool hovered: false
        property bool closeMode: false     // docked on the open chat: shows ✕
        property bool backdrop: true

        Rectangle {
            visible: face.backdrop
            anchors.centerIn: parent
            width: 48
            height: 48
            radius: 24
            color: Qt.rgba(0, 0, 0, face.hovered ? 0.35 : 0.25)
        }
        LogoCircle {
            id: faceCircle
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            size: face.hovered ? 46 : 44
            accent: root.pillTransparent ? "transparent" : root.accent   // same style as the bar icon
            logoScale: root.pillTransparent ? 0.75 : 0.62
            logoPath: root.logoPath
            hasLogo: root.hasLogo
            visible: !face.closeMode
            Behavior on size {
                NumberAnimation { duration: 100 }
            }
            SequentialAnimation on opacity {
                running: root.busy
                loops: Animation.Infinite
                onStopped: faceCircle.opacity = 1
                NumberAnimation { to: 0.5; duration: 600; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutQuad }
            }
        }
        Rectangle {
            visible: face.closeMode
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            width: face.hovered ? 46 : 44
            height: width
            radius: width / 2
            color: root.pillTransparent ? Theme.surfaceContainerHighest : root.accent
            DIcon {
                anchors.centerIn: parent
                name: "close"
                size: 24
                color: "white"
                rotation: face.closeMode ? 0 : -90
                Behavior on rotation {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // Thin, rounded scrollbar: only the handle, shown while scrolling or hovered.
    component ThinScrollBar: ScrollBar {
        id: bar
        leftPadding: 3
        rightPadding: 3
        topPadding: 3
        bottomPadding: 3
        background: Item {}
        contentItem: Rectangle {
            implicitWidth: bar.hovered || bar.pressed ? 6 : 4
            radius: width / 2
            color: Theme.withAlpha(Theme.onSurface, bar.pressed ? 0.5 : (bar.hovered ? 0.35 : 0.22))
            opacity: bar.size < 1 && (bar.active || bar.hovered) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 250 } }
            Behavior on implicitWidth { NumberAnimation { duration: 120 } }
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
            source: !circle.hasLogo || !circle.logoPath ? "" : (circle.logoPath.startsWith("/") ? "file://" + circle.logoPath
                                                : "file:///" + circle.logoPath.replace(/\\/g, "/"))
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
    readonly property string backend: localPath(Qt.resolvedUrl("backend/duxai.py"))

    // Running inside the Windows app instead of DMS? (Its stand-in for
    // PluginComponent has hostPlatform: "windows"; on DMS this is undefined.)
    readonly property bool onWindows: root.hostPlatform === "windows"

    // Path <-> file URL, for Linux (/home/..) and Windows (C:\Users\..) paths.
    function fileUrl(path) {
        if (!path)
            return "";
        return path.startsWith("/") ? "file://" + path : "file:///" + path.replace(/\\/g, "/");
    }
    function localPath(url) {
        const p = decodeURIComponent(String(url).replace(/^file:\/\//, ""));
        return /^\/[A-Za-z]:/.test(p) ? p.slice(1) : p;   // "/C:/x" -> "C:/x"
    }
    property string modelOverride: ""
    property string effortOverride: ""
    readonly property string model: modelOverride || pluginData.model || "sonnet"
    readonly property string effort: effortOverride || pluginData.effort || "medium"
    // Quick settings (gear in the chat header); also in the plugin settings page.
    property bool allowWeb: pluginData.allowWeb ?? false
    property bool screenViewer: pluginData.screenViewer ?? true   // Claude may look at the screen when needed
    // Floating bubble: a small draggable button that stays on top (handy during lectures).
    property bool floatingBubble: pluginData.floatingBubble ?? false
    property real bubbleRight: pluginData.bubbleRight ?? 24      // distance to the right screen edge
    property real bubbleBottom: pluginData.bubbleBottom ?? 96    // distance to the bottom screen edge
    readonly property int bubbleSize: 56
    // Which monitor the bubble is on (by name; drag it to another monitor to move it there).
    property string bubbleScreenName: pluginData.bubbleScreen ?? ""
    readonly property var allScreens: (root.onWindows ? Qt.application.screens : Quickshell.screens) ?? []
    readonly property var bubbleScreen: {
        for (const s of allScreens)
            if (s.name === bubbleScreenName)
                return s;
        return root.parentScreen;    // not set yet, or that monitor is unplugged
    }
    // Position + size of a screen on the whole desktop (Quickshell: x/y, Qt: virtualX/virtualY).
    function screenRect(s) {
        return { x: s?.x ?? s?.virtualX ?? 0, y: s?.y ?? s?.virtualY ?? 0, w: s?.width ?? 1920, h: s?.height ?? 1080 };
    }
    // Where the bubble can live: the screen, minus the taskbar on Windows (the
    // bubble's margins are measured from the edges of this area).
    function workRect(s) {
        if (onWindows) {
            const a = dux.workAreaOf(s?.name ?? "");
            return { x: a.x, y: a.y, w: a.width, h: a.height };
        }
        return screenRect(s);
    }
    function screenAt(x, y) {
        for (const s of allScreens) {
            const r = screenRect(s);
            if (x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h)
                return s;
        }
        return null;
    }
    // Keep the bubble on its screen (also fixes a saved position that's off-screen).
    function clampRight(v) {
        return Math.min(Math.max(v, 0), workRect(bubbleScreen).w - bubbleSize);
    }
    function clampBottom(v) {
        return Math.min(Math.max(v, 0), workRect(bubbleScreen).h - bubbleSize);
    }

    function setQuick(key, value) {
        if (key === "allowWeb")
            allowWeb = value;
        else if (key === "screenViewer")
            screenViewer = value;
        else if (key === "floatingBubble")
            floatingBubble = value;
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
    // "Theme accent": DMS's theme colour, or Windows' accent colour.
    readonly property color accent: useThemeColor ? (Theme.systemAccent ?? Theme.primary) : "#D97757"
    readonly property bool pillTransparent: pluginData.pillColor === "transparent"
    readonly property bool showBorder: pluginData.showBorder ?? true
    readonly property bool showUsage: pluginData.showUsage ?? true

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
    property var permission: null       // { id, summary, plain, reason } while Claude waits for Allow/Deny
    property bool permCommandShown: false   // approval card: exact command expanded?
    property string windowApp: ""       // active window when the chat was opened
    property string windowTitle: ""
    readonly property string windowText: windowApp ? windowApp + (windowTitle ? " — " + windowTitle : "") : ""
    property var tokens: null           // { total, context, last: { input, cached, output } }
    // Subscription usage, as Claude Code reports it with every answer:
    // { five_hour: { pct, resets_at }, seven_day: { pct, resets_at } } (either may be missing).
    property var limits: ({})
    readonly property var fiveHour: limits?.five_hour && limits.five_hour.resets_at * 1000 > Date.now() ? limits.five_hour : null

    function refreshLimits() {
        Proc.runCommand("duxAi.limits", ["python3", backend, "limits"], out => {
            const ev = lastJson(out);
            if (ev?.type === "limits")
                limits = ev.limits || {};
        });
    }

    function fmtTokens(n) {
        n = n || 0;
        return n < 1000 ? String(n) : (n < 100000 ? (n / 1000).toFixed(1) : Math.round(n / 1000)) + "k";
    }

    property bool followEnd: true       // auto-scroll to new text; off while the user has scrolled up

    signal focusInput
    signal scrollToEnd

    ListModel {
        id: messages   // { role, text, image, quote, window, steps, isError, math, html }
    }

    // ---- math: formulas drawn as images by the backend (see render_math) ----
    // How formulas should look: text colour, size and the font's x-height (to
    // line them up with the text).
    FontMetrics {
        id: bodyMetrics
        font.pixelSize: root.fsBody
    }
    // Formulas are drawn for the scaling of the screen the chat is on (1.25 at
    // 125%) so they're shown pixel for pixel, as sharp as the text.
    property real chatScale: 1
    readonly property string mathStyle: String(Theme.onSurface).slice(0, 7) + "," + root.fsBody + "," + bodyMetrics.xHeight.toFixed(2)
                                        + "," + chatScale
    // Chat moved to a screen with other scaling: draw its formulas again for it.
    onChatScaleChanged: {
        let hasMath = false;
        for (let i = 0; i < messages.count; i++)
            hasMath = hasMath || messages.get(i).math !== "";
        if (hasMath && chatId && !busy)
            openChat(chatId);
    }

    // Markdown -> HTML, so formula images can be put in (Qt's Markdown can't hold them).
    TextEdit {
        id: mdConverter
        visible: false
        textFormat: TextEdit.MarkdownText
        font.pixelSize: root.fsBody
    }

    function markdownToHtml(md) {
        // Load it as Markdown, then switch to rich text: Qt then hands back HTML.
        mdConverter.textFormat = TextEdit.MarkdownText;
        mdConverter.text = md;
        mdConverter.textFormat = TextEdit.RichText;
        return mdConverter.text.replace(/<body[^>]*>/, "<body>")    // keep the chat's own font and size
                          .replace(/color:#0000ff/g, "color:" + String(root.accent).slice(0, 7));   // links: accent, not default blue
    }

    // An answer as rich text (always: switching a text box between Markdown
    // and rich text loses the text). With formulas: the Markdown around them as
    // usual, each formula an image (inline on the text line, display ones
    // centred). Clicking a formula copies its LaTeX.
    function answerHtml(text, json) {
        let pieces = null;
        try {
            pieces = json ? JSON.parse(json) : null;
        } catch (e) {}
        if (!pieces)
            return markdownToHtml(text);
        // While an answer streams in, the drawn formulas cover only the text so
        // far: show the rest of the text behind them as it arrives.
        const covered = pieces.map(p => p.t !== undefined ? p.t : p.raw).join("");
        if (!text.startsWith(covered))
            return markdownToHtml(text);
        let md = "";
        pieces.forEach((p, i) => {
            if (p.t !== undefined)
                md += p.t;
            else
                md += p.display ? "\n\nARGOSMATH" + i + "Z\n\n" : "ARGOSMATH" + i + "Z";
        });
        md += text.slice(covered.length);
        let html = markdownToHtml(md);
        const img = p => "<a href=\"latex:" + encodeURIComponent(p.m) + "\"><img src=\"" + p.src + "\" width=\"" + p.w
                         + "\" height=\"" + p.h + "\" style=\"vertical-align: middle\"></a>";
        // Display formulas: their own centred paragraph (&nbsp; around it: Qt won't centre a lone image).
        html = html.replace(/<p([^>]*)>\s*ARGOSMATH(\d+)Z\s*<\/p>/g,
                            (all, attrs, i) => "<p" + attrs.replace(/margin-top:\d+px/, "margin-top:12px").replace(/margin-bottom:\d+px/, "margin-bottom:12px")
                                               + " align=\"center\">&nbsp;" + img(pieces[i]) + "&nbsp;</p>");
        return html.replace(/ARGOSMATH(\d+)Z/g, (all, i) => img(pieces[i]));
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
        if (interactionActive) {
            fetchWindow();
            refreshLimits();
        }
    }

    // ------------------------------------------------------- popout control --
    // The chat can be open in two places: the normal DMS popout (bar button)
    // or the bubble chat (floating bubble, shown above fullscreen video).
    property bool bubbleChatOpen: false
    // The chat that belongs to the bubble is on screen (DMS: bubble chat; Windows: popup opened from the bubble).
    readonly property bool bubbleChatShown: onWindows ? (interactionActive && popupAnchor !== null && popupAnchor !== undefined)
                                                      : bubbleChatOpen

    // Windows: pinned = the chat stays open when you click somewhere else
    // (close it with Esc, the tray icon or the shortcut). Not on DMS: there
    // the bubble chat always stays open and lets other apps have the keyboard.
    property bool pinned: onWindows && (pluginData.pinned ?? false)

    function togglePin() {
        pinned = !pinned;
        pluginService?.savePluginData("duxAi", "pinned", pinned);
    }
    property bool reopenInBubble: false     // after a screenshot/selection, come back in the bubble chat
    readonly property bool chatVisible: interactionActive || bubbleChatOpen

    // Turning the bubble on from the bar chat closes that chat (the bubble takes over);
    // turning it off (e.g. in the gear menu of the bubble chat) closes the bubble's chat.
    onFloatingBubbleChanged: {
        if (floatingBubble) {
            if (root.interactionActive)
                root.closePopout();
        } else {
            bubbleChatOpen = false;
            if (typeof root.closeBubblePopup === "function")
                root.closeBubblePopup();          // Windows: the popup opened next to the bubble
        }
    }

    // The gear menu closes together with the chat.
    onChatVisibleChanged: {
        if (!chatVisible)
            quickSettingsOpen = false;
        else
            unreadAnswer = false;
    }

    // Windows: the tray icon shows a dot while Claude works ("busy") and when
    // an answer came in while the chat was closed ("done", until you open it).
    property bool unreadAnswer: false
    onBusyChanged: {
        if (!busy && !chatVisible)
            unreadAnswer = true;
    }
    readonly property string trayState: busy ? "busy" : unreadAnswer ? "done" : ""
    onTrayStateChanged: {
        if (onWindows)
            dux.setTrayState(trayState);
    }

    onBubbleChatOpenChanged: {
        if (bubbleChatOpen) {
            fetchWindow();
            focusTimer.restart();
        }
    }

    function openPopout() {
        if (reopenInBubble || bubbleChatOpen) {
            reopenInBubble = false;
            openBubbleChat();
            return;
        }
        if (!root.interactionActive)
            root.triggerPopout();
        focusTimer.restart();
    }

    // While Claude takes a screenshot (screen viewer), our windows step aside.
    property bool hidingForScreenshot: false
    property var shownBeforeScreenshot: null

    function hideForScreenshot() {
        shownBeforeScreenshot = { popout: root.interactionActive, bubbleChat: bubbleChatOpen };
        hidingForScreenshot = true;
        bubbleChatOpen = false;
        if (root.interactionActive)
            root.closePopout();
    }

    function restoreAfterScreenshot() {
        hidingForScreenshot = false;        // bubble back first, the chat right after
        reopenTimer.restart();
    }

    Timer {
        id: reopenTimer
        interval: 60
        onTriggered: {
            const was = root.shownBeforeScreenshot || {};
            root.shownBeforeScreenshot = null;
            if (was.bubbleChat)
                root.bubbleChatOpen = true;
            else if (was.popout && !root.interactionActive)
                root.triggerPopout();
            focusTimer.restart();
        }
    }

    function openBubbleChat() {
        if (root.onWindows && typeof root.showPopupNear === "function")
            root.showPopupNear(bubble.x, bubble.y, root.bubbleSize, true);   // Windows: normal popup, next to the bubble
        else
            bubbleChatOpen = true;
    }

    function toggleBubbleChat() {
        if (root.onWindows && typeof root.showPopupNear === "function")
            root.showPopupNear(bubble.x, bubble.y, root.bubbleSize, false);  // toggles
        else
            bubbleChatOpen = !bubbleChatOpen;
    }

    // Called by `dms ipc call widget openWith duxAi <mode>` (keyboard shortcut).
    function openWithMode(mode) {
        if (mode === "capture")
            startCapture();
        else if (mode === "text")
            grabSelection();
        else if (mode === "screenshot-hide")
            hideForScreenshot();
        else if (mode === "screenshot-restore")
            restoreAfterScreenshot();
        else
            openPopout();
    }

    Timer {
        id: focusTimer
        interval: 80
        onTriggered: root.focusInput()
    }

    // ------------------------------------------------------------- capture --
    function startCapture(fromBubble) {
        fetchWindow();
        reopenInBubble = fromBubble === true || bubbleChatOpen;
        bubbleChatOpen = false;
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
                ToastService.showError("Argos: " + ev.message);
            }
            root.openPopout();
        })
    }

    // Text highlighted anywhere on screen (Wayland primary selection).
    function grabSelection() {
        fetchWindow();
        reopenInBubble = bubbleChatOpen;
        Proc.runCommand("duxAi.selection", ["python3", root.backend, "selection"], (out, code) => {
            const ev = root.lastJson(out);
            if (ev?.type === "selection") {
                root.pendingQuote = ev.text;
                root.view = "chat";
            } else if (ev?.type === "error") {
                ToastService.showError("Argos: " + ev.message);
            }
            root.openPopout();
        });
    }

    // ---------------------------------------------------------------- chat --
    function shortTitle(text) {
        text = text.replace(/\s+/g, " ").trim();
        return text.length > 48 ? text.slice(0, 48) + "…" : (text || "Screenshot");
    }

    // One small Haiku call per chat (~100-300 tokens); the first-sentence title stays if it fails.
    function requestTitle(id) {
        Proc.runCommand("duxAi.title", ["python3", backend, "title", id], out => {
            const ev = lastJson(out);
            if (ev?.type === "title" && ev.title && chatId === ev.chat)
                chatTitle = ev.title;
            refreshHistory();
        });
    }

    function send(text) {
        text = text.trim();
        if (busy || (!text && !pendingImage && !pendingQuote))
            return false;

        const win = includeWindow ? windowText : "";   // sent along invisibly
        messages.append({ role: "user", text: text, image: pendingImage, quote: pendingQuote, window: win, steps: "", isError: false, math: "", html: "" });
        messages.append({ role: "assistant", text: "", image: "", quote: "", window: "", steps: "", isError: false, math: "", html: "" });
        if (!chatId)
            chatTitle = shortTitle(text || pendingQuote);

        const cmd = ["python3", backend, "ask", "--model=" + model, "--effort=" + effort,
                     "--max-image-side=" + maxImageSide, "--math=" + mathStyle];
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
        followEnd = true;   // a new message always jumps to the bottom
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
        setAnswer(last, text, messages.get(last).math);
        messages.setProperty(last, "isError", !!isError);
    }

    // An answer's text, its formulas (JSON from the backend) and the rich text
    // the chat shows. Made here, once per change: in the chat list itself it
    // would be made again for every message that scrolls into view.
    function setAnswer(i, text, math) {
        messages.set(i, { text: text, math: math, html: answerHtml(text, math) });
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
                setAnswer(last, messages.get(last).text + ev.text, messages.get(last).math);
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
            permCommandShown = false;
            permission = { id: ev.id, summary: ev.summary, plain: ev.plain || "", reason: ev.reason || "" };
            scrollToEnd();
            break;
        case "limits":
            limits = ev.limits || {};
            break;
        case "math":            // formulas drawn while the answer streams in
            if (last >= 0)
                setAnswer(last, messages.get(last).text, JSON.stringify(ev.math));
            break;
        case "permission_cancel":
            if (permission && permission.id === ev.id)
                permission = null;
            break;
        case "done":
            gotFinal = true;
            if (ev.tokens)
                tokens = ev.tokens;
            if (last >= 0) {
                setAnswer(last, ev.text, ev.math ? JSON.stringify(ev.math) : "");
                messages.setProperty(last, "isError", false);
            }
            scrollToEnd();
            if (ev.chat && !ev.stopped && messages.count === 2)
                requestTitle(ev.chat);   // first answer finished: ask Haiku for a short title
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
        Proc.runCommand("duxAi.load", ["python3", backend, "load", id, "--math=" + mathStyle], out => {
            const ev = lastJson(out);
            if (ev?.type !== "chat")
                return;
            messages.clear();
            for (const m of ev.chat.messages) {
                const math = m.math ? JSON.stringify(m.math) : "";
                messages.append({ role: m.role, text: m.text || "", image: m.image || "", quote: m.quote || "", window: m.window || "",
                                  steps: (m.steps || []).join("\n"), isError: false, math: math,
                                  html: m.role === "user" ? "" : answerHtml(m.text || "", math) });
            }
            chatId = ev.chat.id;
            chatTitle = ev.chat.title;
            tokens = ev.tokens || null;
            view = "chat";
            followEnd = true;
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
        refreshLimits();
        Proc.runCommand("duxAi.logo", ["python3", backend, "logo"], out => {
            const ev = lastJson(out);
            logoPath = ev?.path || "";
        });
    }

    // ------------------------------------------------- permission popup --
    // Small Allow/Deny card, shown only while Claude waits for approval and the
    // chat window is closed. Opening the chat hides it.
    // DMS: under the bar. Windows: bottom-right, just above the tray (also
    // when you chat from the floating bubble).
    PanelWindow {
        id: permPopup
        visible: root.permission !== null && !root.chatVisible
        screen: root.parentScreen ?? null
        color: "transparent"
        anchors { top: !root.onWindows; bottom: root.onWindows; right: true }
        margins { top: root.barThickness + 8; right: 12; bottom: 12 }
        implicitWidth: 340
        implicitHeight: permBox.implicitHeight
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "dux-ai:permission"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: permBox
            width: parent.width
            implicitHeight: permBody.implicitHeight + 24
            radius: Theme.cornerRadius
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.withAlpha(root.accent, 0.6)

            Column {
                id: permBody
                x: 12
                y: 12
                width: parent.width - 24
                spacing: 8

                StyledText {
                    text: "Claude wants to:"
                    font.pixelSize: root.fsSmall
                    font.weight: Font.Medium
                    color: Theme.onSurface
                }
                StyledText {
                    width: parent.width
                    text: root.permission ? (root.permission.plain !== "" ? root.permission.plain : root.permission.summary) : ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 5
                    elide: Text.ElideRight
                    font.pixelSize: root.fsSmall
                    color: Theme.onSurface
                }
                Row {
                    anchors.right: parent.right
                    spacing: 8
                    Rectangle {
                        width: popOpenText.implicitWidth + 24
                        height: 30
                        radius: 15
                        color: Theme.withAlpha(Theme.onSurface, popOpenMouse.containsMouse ? 0.14 : 0.07)
                        StyledText { id: popOpenText; anchors.centerIn: parent; text: "Open chat"; font.pixelSize: root.fsSmall; color: Theme.onSurface }
                        MouseArea { id: popOpenMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openPopout() }
                    }
                    Rectangle {
                        width: popDenyText.implicitWidth + 24
                        height: 30
                        radius: 15
                        color: Theme.withAlpha(Theme.onSurface, popDenyMouse.containsMouse ? 0.14 : 0.07)
                        StyledText { id: popDenyText; anchors.centerIn: parent; text: "Deny"; font.pixelSize: root.fsSmall; color: Theme.onSurface }
                        MouseArea { id: popDenyMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.answerPermission(false) }
                    }
                    Rectangle {
                        width: popAllowText.implicitWidth + 24
                        height: 30
                        radius: 15
                        color: popAllowMouse.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent
                        StyledText { id: popAllowText; anchors.centerIn: parent; text: "Allow"; font.pixelSize: root.fsSmall; font.weight: Font.Medium; color: "white" }
                        MouseArea { id: popAllowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.answerPermission(true) }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------- floating bubble --
    // Settings → "Floating bubble". Drag it anywhere; click = chat,
    // right-click = ask about a screen region. Stays above fullscreen video.
    //
    // Dragging: the bubble itself stays put while a see-through copy follows
    // the mouse (dragLayer); it moves once, when you let go. Moving the real
    // window during the drag doesn't work well: the compositor moves it a
    // moment later, so mouse positions are measured from the wrong place.
    PanelWindow {
        id: bubble
        // DMS: stays next to its open chat and shows ✕. Windows: hidden while
        // its chat is open (the chat takes the bubble's place).
        visible: root.floatingBubble && !root.hidingForScreenshot && !(root.onWindows && root.bubbleChatShown)
        screen: root.bubbleScreen ?? null
        color: "transparent"
        anchors { bottom: true; right: true }
        margins { bottom: root.clampBottom(root.bubbleBottom); right: root.clampRight(root.bubbleRight) }
        implicitWidth: root.bubbleSize
        implicitHeight: root.bubbleSize
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "dux-ai:bubble"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        BubbleFace {
            anchors.fill: parent
            hovered: bubbleMouse.containsMouse
            closeMode: root.bubbleChatOpen && !root.onWindows
            opacity: bubbleMouse.dragged ? 0 : 1      // only the copy under the mouse shows while dragging
        }

        MouseArea {
            id: bubbleMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: dragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            property real pressX: 0
            property real pressY: 0
            property real startRight: 0
            property real startBottom: 0
            // Where the bubble copy is during a drag, on the whole desktop (all monitors).
            property real ghostX: 0
            property real ghostY: 0
            property bool dragged: false

            onPressed: mouse => beginDrag(mouse.x, mouse.y)
            onPositionChanged: mouse => {
                if (pressed && mouse.buttons === Qt.LeftButton)
                    moveDrag(mouse.x, mouse.y);
            }

            // Shared with the bubble docked on the chat (DMS): positions are
            // in the coordinates of whichever window was pressed; neither
            // window moves during the drag.
            function beginDrag(x, y) {
                pressX = x;
                pressY = y;
                startRight = bubble.margins.right;
                startBottom = bubble.margins.bottom;
                dragged = false;
            }
            function moveDrag(mx, my) {
                const dx = mx - pressX, dy = my - pressY;
                if (!dragged && Math.abs(dx) + Math.abs(dy) < 4)
                    return;
                dragged = true;
                // The bubble doesn't move during the drag, so this is exact.
                const from = root.workRect(root.bubbleScreen);
                const x = from.x + from.w - startRight - root.bubbleSize + dx;
                const y = from.y + from.h - startBottom - root.bubbleSize + dy;
                // Keep it on the monitor under the mouse (or the one it's on).
                const r = root.workRect(root.screenAt(x + root.bubbleSize / 2, y + root.bubbleSize / 2) ?? root.bubbleScreen);
                ghostX = Math.min(Math.max(x, r.x), r.x + r.w - root.bubbleSize);
                ghostY = Math.min(Math.max(y, r.y), r.y + r.h - root.bubbleSize);
            }

            function finishDrag() {
                // Where did it land? Maybe on another monitor.
                const target = root.screenAt(ghostX + root.bubbleSize / 2, ghostY + root.bubbleSize / 2) ?? root.bubbleScreen;
                const to = root.workRect(target);
                root.bubbleScreenName = target?.name ?? "";
                root.bubbleRight = root.clampRight(to.x + to.w - ghostX - root.bubbleSize);
                root.bubbleBottom = root.clampBottom(to.y + to.h - ghostY - root.bubbleSize);
                if (target?.name)
                    pluginService?.savePluginData("duxAi", "bubbleScreen", target.name);
                pluginService?.savePluginData("duxAi", "bubbleRight", Math.round(root.bubbleRight));
                pluginService?.savePluginData("duxAi", "bubbleBottom", Math.round(root.bubbleBottom));
                dragged = false;
            }
            // If the system takes the mouse away mid-drag, still put the bubble where it was.
            onCanceled: {
                if (dragged)
                    finishDrag();
            }
            onReleased: mouse => {
                if (dragged) {
                    finishDrag();
                } else if (mouse.button === Qt.RightButton) {
                    root.startCapture(true);
                } else {
                    root.toggleBubbleChat();
                }
                dragged = false;
            }
        }
    }

    // The chat, opened from the floating bubble (DMS). Same content as the bar
    // popout, but on the overlay layer, so it shows above fullscreen video.
    // Docked right next to the bubble (which shows ✕ meanwhile): above it,
    // below it, or beside it, flush with the bubble's outer side so the two
    // fit tight in a screen corner. It stays open when you click elsewhere and
    // lets other apps have the keyboard; ✕ or Esc closes it.
    PanelWindow {
        id: bubbleChat
        visible: root.bubbleChatOpen && !root.onWindows
        screen: root.bubbleScreen ?? null
        color: "transparent"
        anchors { top: true; left: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "dux-ai:chat"
        WlrLayershell.layer: WlrLayer.Overlay
        // Keyboard right away, then "on demand": clicking another window gives it the keyboard.
        WlrLayershell.keyboardFocus: grabKeys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
        property bool grabKeys: true
        onVisibleChanged: {
            if (visible) {
                grabKeys = true;
                keysTimer.restart();
                chatFrame.scale = 0.85;      // start state first, so it never flashes at full size
                chatFrame.opacity = 0;
                growAnim.restart();
            }
        }
        Timer {
            id: keysTimer
            interval: 600
            onTriggered: bubbleChat.grabKeys = false
        }

        readonly property real pad: PopoutMetrics.contentPadding
        readonly property var area: root.screenRect(root.bubbleScreen)
        readonly property real s: root.bubbleSize
        readonly property real gap: 6
        readonly property real cw: root.popoutWidth
        readonly property real ch: Math.min((chatLoader.item ? chatLoader.item.implicitHeight : root.popoutHeight) + 2 * pad, area.h - 16)
        // The bubble, measured from this screen's top-left corner.
        readonly property real bx: area.w - bubble.margins.right - s
        readonly property real by: area.h - bubble.margins.bottom - s
        readonly property bool rightHalf: bx + s / 2 > area.w / 2
        readonly property bool lowerHalf: by + s / 2 > area.h / 2
        readonly property bool fitsAbove: by - gap - ch >= 0
        readonly property bool fitsBelow: by + s + gap + ch <= area.h
        readonly property string mode: lowerHalf ? (fitsAbove ? "above" : fitsBelow ? "below" : "side")
                                                 : (fitsBelow ? "below" : fitsAbove ? "above" : "side")
        function clamp(v, lo, hi) {
            return Math.min(Math.max(v, lo), Math.max(lo, hi));
        }
        margins {
            left: bubbleChat.mode === "side" ? (bubbleChat.rightHalf ? bubbleChat.bx - bubbleChat.gap - bubbleChat.cw : bubbleChat.bx + bubbleChat.s + bubbleChat.gap)
                : bubbleChat.clamp(bubbleChat.rightHalf ? bubbleChat.bx + bubbleChat.s - bubbleChat.cw : bubbleChat.bx, 0, bubbleChat.area.w - bubbleChat.cw)
            top: bubbleChat.mode === "above" ? bubbleChat.by - bubbleChat.gap - bubbleChat.ch
               : bubbleChat.mode === "below" ? bubbleChat.by + bubbleChat.s + bubbleChat.gap
               : bubbleChat.clamp(bubbleChat.lowerHalf ? bubbleChat.by + bubbleChat.s - bubbleChat.ch : bubbleChat.by, 0, bubbleChat.area.h - bubbleChat.ch)
        }
        implicitWidth: cw
        implicitHeight: ch

        Item {
            id: chatFrame
            anchors.fill: parent
            // Grows out of the bubble's side.
            transformOrigin: bubbleChat.mode === "side" ? (bubbleChat.rightHalf ? (bubbleChat.lowerHalf ? Item.BottomRight : Item.TopRight)
                                                                                : (bubbleChat.lowerHalf ? Item.BottomLeft : Item.TopLeft))
                           : bubbleChat.mode === "above" ? (bubbleChat.rightHalf ? Item.BottomRight : Item.BottomLeft)
                           : (bubbleChat.rightHalf ? Item.TopRight : Item.TopLeft)
            ParallelAnimation {
                id: growAnim
                NumberAnimation { target: chatFrame; property: "scale"; from: 0.85; to: 1; duration: 160; easing.type: Easing.OutCubic }
                NumberAnimation { target: chatFrame; property: "opacity"; from: 0; to: 1; duration: 120 }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.windowRadius
                color: Theme.surfaceContainer
                border.width: 1
                border.color: Theme.withAlpha(Theme.onSurface, 0.08)
            }
            Loader {
                id: chatLoader
                x: bubbleChat.pad
                y: bubbleChat.pad
                width: parent.width - 2 * bubbleChat.pad
                active: bubbleChat.visible
                focus: true
                sourceComponent: root.popoutContent
                Keys.onEscapePressed: root.bubbleChatOpen = false
            }
        }
    }

    // A full-screen, click-through layer on every monitor that only shows the
    // bubble copy while dragging (so you can drag it to another monitor). They
    // exist as long as the bubble does (empty otherwise): a new window
    // appearing mid-drag would take the mouse away from the bubble.
    Instantiator {
        model: root.floatingBubble ? root.allScreens : []

        delegate: PanelWindow {
            id: dragLayer
            required property var modelData
            readonly property var area: root.workRect(modelData)
            visible: true
            screen: modelData
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            WlrLayershell.namespace: "dux-ai:bubble-drag"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            BubbleFace {
                visible: bubbleMouse.dragged
                width: root.bubbleSize
                height: root.bubbleSize
                // Desktop position -> position on this monitor (off-window = not drawn here).
                x: bubbleMouse.ghostX - dragLayer.area.x
                y: bubbleMouse.ghostY - dragLayer.area.y
                hovered: true
            }
        }
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

            // The scaling of the screen this chat is on (for drawing formulas).
            readonly property real screenScale: Screen.devicePixelRatio
            onScreenScaleChanged: root.chatScale = Math.max(1, screenScale)

            // How far the chat list reaches under the input box. Only when nothing sits
            // between them (no approval card / attachment), since those are see-through.
            readonly property real listOverlap: (inputBox.visible && root.permission === null
                                                 && root.pendingImage === "" && root.pendingQuote === "")
                                                ? inputBox.height / 2 + Theme.spacingS : 0   // ends mid-box: hidden behind the straight part, never in the rounded corners

            Connections {
                target: root
                function onFocusInput() {
                    if (root.view === "chat")
                        input.forceActiveFocus();
                }
                function onScrollToEnd() {
                    if (root.followEnd)
                        Qt.callLater(() => chatList.snapToEnd());
                }
                function onInteractionActiveChanged() {
                    if (root.interactionActive)
                        focusTimer.restart();
                }
            }
            Component.onCompleted: {
                root.chatScale = Math.max(1, screenScale);
                focusTimer.restart();
            }

            // Thin outline along the edge of the popout (Settings: "Window border").
            Rectangle {
                visible: root.showBorder
                anchors.fill: parent
                anchors.margins: -PopoutMetrics.contentPadding
                radius: Theme.windowRadius
                color: "transparent"
                border.width: 2
                border.color: Theme.withAlpha(root.accent, 0.6)
                z: 100
            }

            // Click anywhere next to the gear menu: close it (the click does nothing else).
            MouseArea {
                visible: root.quickSettingsOpen
                z: 199
                anchors.fill: parent
                anchors.margins: -PopoutMetrics.contentPadding   // also the window's edge
                acceptedButtons: Qt.AllButtons
                onPressed: root.quickSettingsOpen = false
                onWheel: wheel => wheel.accepted = true
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
                    SwitchRow {
                        width: parent.width
                        icon: "chat_bubble"
                        label: "Floating bubble"
                        hint: "A small button that stays on top, also over fullscreen video"
                        checked: root.floatingBubble
                        onToggled: root.setQuick("floatingBubble", !root.floatingBubble)
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
                        icon: "add"
                        iconSize: 20
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
                        visible: root.onWindows
                        icon: "keep"            // pin (Windows): stay open when you click elsewhere
                        filled: root.pinned
                        active: root.pinned
                        onClicked: root.togglePin()
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
                            text: "Ask me anything."
                            font.pixelSize: root.fsTitle
                            color: Theme.onSurface
                        }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: win.width - 60
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: "Give me eyes by using the selection tools or Screen-viewer mode to give me context about your screen."
                            font.pixelSize: root.fsSmall
                            color: Theme.onSurfaceVariant
                        }
                    }

                    // "Jump to bottom" button: shown when scrolled up.
                    Rectangle {
                        z: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        width: 44
                        height: 22
                        radius: 11
                        // Only when well above the bottom (more than ~160 px behind).
                        readonly property bool farBehind: chatList.contentHeight + chatList.bottomMargin - chatList.height - (chatList.contentY - chatList.originY) > 160
                        visible: opacity > 0
                        opacity: messages.count > 0 && farBehind ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        // Solid (alpha forced to 1): theme surfaces can be see-through.
                        color: {
                            const c = jumpMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh;
                            return Qt.rgba(c.r, c.g, c.b, 1);
                        }
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.onSurface, 0.18)

                        DIcon {
                            anchors.centerIn: parent
                            name: "keyboard_arrow_down"
                            size: 16
                            color: jumpMouse.containsMouse ? root.accent : Theme.onSurfaceVariant
                        }
                        MouseArea {
                            id: jumpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.followEnd = true;
                                chatList.snapToEnd();
                            }
                        }
                    }

                    ListView {
                        id: chatList
                        // The list runs under the input box (which is drawn on top of it),
                        // so text scrolls behind the input instead of stopping at a hard edge.
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -win.listOverlap
                        bottomMargin: win.listOverlap    // so the last line can scroll up above the input
                        clip: true
                        spacing: Theme.spacingM
                        model: messages
                        // Keep every message built (a chat is small): the list then knows its real
                        // height, so the scrollbar doesn't jump while you scroll.
                        cacheBuffer: 1000000
                        boundsBehavior: Flickable.StopAtBounds
                        // Scrolling up stops the auto-follow; reaching the bottom again resumes it.
                        onMovementStarted: root.followEnd = false
                        onMovementEnded: root.followEnd = nearEnd()
                        maximumFlickVelocity: 5000

                        // Distance (px) between the visible bottom and the end of the chat.
                        function distToEnd() {
                            return contentHeight + bottomMargin - height - (contentY - originY);
                        }
                        // "At the bottom" also counts when only a few lines short of it.
                        function nearEnd() {
                            return distToEnd() < 48;
                        }
                        // The list got taller/shorter (input box grew or shrank): stay at the bottom if we were.
                        // Jump to the very end, including the bottom margin that keeps the last
                        // line above the input box (positionViewAtEnd() alone can ignore it).
                        function snapToEnd() {
                            positionViewAtEnd();
                            contentY = Math.max(originY - topMargin, originY + contentHeight + bottomMargin - height);
                        }
                        onHeightChanged: if (root.followEnd) Qt.callLater(() => chatList.snapToEnd())
                        onBottomMarginChanged: if (root.followEnd) Qt.callLater(() => chatList.snapToEnd())
                        // New content (e.g. your message after sending): same.
                        onContentHeightChanged: if (root.followEnd) Qt.callLater(() => chatList.snapToEnd())
                        flickDeceleration: 2200

                        // Mouse wheel: handled here so following stops on the very first click.
                        // (Qt's own wheel scrolling reports "movement" a bit late; meanwhile the
                        // list re-measures messages above you and following pulled you back down.)
                        WheelHandler {
                            id: mouseScroll
                            acceptedDevices: PointerDevice.Mouse
                            property real target: 0
                            onWheel: event => {
                                root.followEnd = false;
                                const minY = chatList.originY - chatList.topMargin;
                                const maxY = Math.max(minY, chatList.originY + chatList.contentHeight + chatList.bottomMargin - chatList.height);
                                const from = wheelAnim.running ? target : chatList.contentY;
                                target = Math.max(minY, Math.min(maxY, from - event.angleDelta.y / 120 * 72));
                                wheelAnim.stop();
                                wheelAnim.to = target;
                                wheelAnim.start();
                                if (target >= maxY - 1)
                                    root.followEnd = true;     // scrolled back to the bottom: follow again
                            }
                        }
                        NumberAnimation {
                            id: wheelAnim
                            target: chatList
                            property: "contentY"
                            duration: 120
                            easing.type: Easing.OutCubic
                        }

                        // Touchpad scrolling with momentum. Wayland only sends the finger movement,
                        // so when the fingers lift we measure the speed and let the list coast.
                        WheelHandler {
                            id: padScroll
                            acceptedDevices: PointerDevice.TouchPad
                            property real velocity: 0      // contentY change in px/s
                            property real lastTime: 0

                            onWheel: event => {
                                const dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 3;
                                if (chatList.flicking)
                                    chatList.cancelFlick();
                                const now = Date.now();
                                const dt = Math.max(1, now - lastTime);
                                const inst = -dy / dt * 1000;
                                velocity = lastTime > 0 && dt < 120 ? velocity * 0.6 + inst * 0.4 : inst;
                                lastTime = now;
                                const minY = chatList.originY - chatList.topMargin;
                                const maxY = Math.max(minY, chatList.originY + chatList.contentHeight + chatList.bottomMargin - chatList.height);
                                chatList.contentY = Math.max(minY, Math.min(maxY, chatList.contentY - dy));
                                root.followEnd = false;
                                coastTimer.restart();
                            }
                        }
                        // No wheel event for a moment = fingers lifted: start the coasting.
                        Timer {
                            id: coastTimer
                            interval: 70
                            onTriggered: {
                                const v = padScroll.velocity;
                                padScroll.velocity = 0;
                                padScroll.lastTime = 0;
                                if (Math.abs(v) > 150)
                                    chatList.flick(0, -v);
                                else
                                    root.followEnd = chatList.nearEnd();
                            }
                        }
                        // Stops above the input box (the list itself runs on under it).
                        ScrollBar.vertical: ThinScrollBar {
                            bottomPadding: win.listOverlap + 3
                            onPressedChanged: root.followEnd = pressed ? false : chatList.nearEnd()
                        }

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
                            required property string html
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
                                                source: root.fileUrl(msg.image)
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
                                            onClicked: Qt.openUrlExternally(root.fileUrl(msg.image))
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
                                        height: 20
                                        // Three dots that blink one after another.
                                        Row {
                                            spacing: 5
                                            anchors.verticalCenter: parent.verticalCenter
                                            Repeater {
                                                model: 3
                                                Rectangle {
                                                    required property int index
                                                    width: 7
                                                    height: 7
                                                    radius: 3.5
                                                    color: Theme.onSurfaceVariant
                                                    opacity: 0.25
                                                    SequentialAnimation on opacity {
                                                        running: parent.visible
                                                        loops: Animation.Infinite
                                                        PauseAnimation { duration: index * 200 }
                                                        NumberAnimation { to: 1; duration: 350; easing.type: Easing.InOutQuad }
                                                        NumberAnimation { to: 0.25; duration: 350; easing.type: Easing.InOutQuad }
                                                        PauseAnimation { duration: (2 - index) * 200 }
                                                    }
                                                }
                                            }
                                        }
                                        StyledText {
                                            visible: root.status !== ""
                                            text: root.status
                                            font.pixelSize: root.fsSmall
                                            color: Theme.onSurfaceVariant
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    TextEdit {
                                        id: body
                                        visible: msg.text !== ""
                                        width: msg.isUser ? Math.min(implicitWidth, content.width) : content.width
                                        // Answers: Markdown turned into rich text, with formulas drawn (see setAnswer).
                                        text: msg.isUser ? msg.text : msg.html
                                        textFormat: msg.isUser ? TextEdit.PlainText : TextEdit.RichText
                                        // Formulas are drawn at exactly their size in screen pixels: show
                                        // them pixel for pixel. Smoothing blurs any that land between pixels,
                                        // and the 1/128 px nudge keeps them off the exact middle between two
                                        // (where the graphics card may round some rows one way, some the other).
                                        smooth: false
                                        transform: Translate { x: 1 / 128; y: 1 / 128 }
                                        wrapMode: TextEdit.Wrap
                                        readOnly: true
                                        selectByMouse: true
                                        color: msg.isError ? Theme.error : Theme.onSurface
                                        selectionColor: Theme.withAlpha(Theme.primary, 0.35)
                                        font.pixelSize: root.fsBody
                                        onLinkActivated: link => {
                                            if (link.startsWith("latex:")) {      // a formula: copy its LaTeX
                                                Quickshell.execDetached(["dms", "cl", "copy", decodeURIComponent(link.slice(6))]);
                                                ToastService.showInfo("Copied LaTeX");
                                            } else {
                                                Qt.openUrlExternally(link);
                                            }
                                        }
                                        HoverHandler {
                                            cursorShape: body.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
                                        }
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
                        ScrollBar.vertical: ThinScrollBar {}

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
                        // Plain-English description first (falls back to the raw command)
                        StyledText {
                            width: parent.width
                            text: root.permission ? (root.permission.plain !== "" ? root.permission.plain : root.permission.summary) : ""
                            wrapMode: Text.Wrap
                            maximumLineCount: 6
                            elide: Text.ElideRight
                            font.pixelSize: root.fsSmall
                            color: Theme.onSurface
                        }
                        // Expandable exact command (only when a plain description exists)
                        StyledText {
                            visible: root.permission !== null && root.permission.plain !== ""
                            text: root.permCommandShown ? "Hide command ▴" : "Show command ▾"
                            font.pixelSize: root.fsSmall - 1
                            color: Theme.onSurfaceVariant
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.permCommandShown = !root.permCommandShown
                            }
                        }
                        StyledText {
                            visible: root.permCommandShown && root.permission !== null && root.permission.plain !== ""
                            width: parent.width
                            text: root.permission ? root.permission.summary : ""
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 6
                            elide: Text.ElideRight
                            font.family: "monospace"
                            font.pixelSize: root.fsSmall - 1
                            color: Theme.onSurfaceVariant
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
                        source: root.fileUrl(root.pendingImage)
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
                    id: inputBox
                    visible: root.view === "chat"
                    Layout.fillWidth: true
                    Layout.preferredHeight: inputCol.implicitHeight + 24   // 14 top + 10 bottom (= side margin)
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.onSurface, 0.06)

                    // Solid backing behind the see-through tint, so chat text scrolling
                    // underneath doesn't show through the input box.
                    Rectangle {
                        z: -1
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.surfaceContainer
                    }
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
                            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

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
                                wrapMode: TextArea.Wrap
                                selectionColor: "#3584e4"
                                selectedTextColor: "white"

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

                            // Discrete counter: tokens in this chat and % of the 5-hour limit used.
                            StyledText {
                                readonly property bool hasTokens: root.tokens !== null && root.tokens.total > 0
                                visible: root.showUsage && (hasTokens || root.fiveHour !== null)
                                textFormat: Text.StyledText
                                // "12.3k tok · 23%" (% of the 5-hour session limit), orange from 80%, red from 95%.
                                text: (hasTokens ? root.fmtTokens(root.tokens.total) + " tok" : "")
                                      + (hasTokens && root.fiveHour ? " · " : "")
                                      + (!root.fiveHour ? "" : root.fiveHour.pct >= 80
                                         ? "<font color='" + (root.fiveHour.pct >= 95 ? Theme.error : root.accent) + "'>" + Math.round(root.fiveHour.pct) + "%</font>"
                                         : Math.round(root.fiveHour.pct) + "%")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.withAlpha(Theme.onSurfaceVariant, 0.75)
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
