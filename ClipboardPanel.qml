pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Right-side clipboard panel window (one instance per screen, shown on active).
PanelWindow {
    id: win

    required property ShellScreen modelData
    property bool isActiveScreen: false
    property bool panelOpen: false
    property var service
    property var pins
    property var theme

    signal requestClose()

    screen: modelData
    visible: win.panelOpen && win.isActiveScreen

    anchors.top: true
    anchors.bottom: true
    anchors.right: true
    margins.top: 6
    margins.bottom: 6
    margins.right: 6
    implicitWidth: 480
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    color: "transparent"

    // Open progress 0..1: full-width slide with a bottle-drop jiggle
    // (OutElastic overshoot + settle, fixed 750ms). No fade.
    // Visible persists while the animation is running.
    property real openProg: 0

    Behavior on openProg {
        // Entrance-only in effect: close hides the window instantly
        // (see visible), the spring-back runs invisibly underneath.
        NumberAnimation {
            duration: 750
            easing.type: Easing.OutElastic
            easing.amplitude: 1.0
            easing.period: 0.35
        }
    }

    onPanelOpenChanged: win.openProg = win.panelOpen ? 1 : 0

    property string query: ""
    // Category filter: all | text | images | links | code | pinned
    property string filterKind: "all"
    // Preview overlay target: null | {source:"history", entry} | {source:"pin", pin}
    property var previewTarget: null
    property string previewText: ""
    property string previewImage: ""
    property string previewMeta: ""
    property bool previewLoading: false
    // Panel-owned hover key ("h<cid>" / "p<created>") — cleared on close
    // so highlights can never stick like per-delegate containsMouse does.
    property string hoverKey: ""
    // Master hover switch: flipped off/on across close/open to reset any
    // frozen Qt hover state in every button area at once.
    property bool hoverLive: true
    // UI font: Caelestia primary (loaded via FontLoader in shell.qml)
    property string uiFont: "Google Sans Flex"
    // Material Symbols, same icon language as the Caelestia shell
    property string iconFont: "Material Symbols Rounded"

    onVisibleChanged: {
        if (visible) {
            win.query = "";
            win.filterKind = "all";
            win.previewTarget = null;
            win.hoverLive = true;
            searchInput.forceActiveFocus();
        } else {
            win.hoverKey = "";
            win.hoverLive = false;
            win.previewTarget = null;
        }
    }

    Shortcut {
        sequences: ["Escape"]
        onActivated: {
            if (win.previewTarget)
                win.previewBack();
            else
                win.requestClose();
        }
    }

    Connections {
        target: win.service

        function onLoadingChanged() {
            if (win.service && win.service.loading)
                win.hoverKey = "";
        }
    }

    function matchQuery(text: string): bool {
        if (win.query === "")
            return true;
        return text.toLowerCase().includes(win.query.toLowerCase());
    }

    function histMatches(): var {
        if (!win.service)
            return [];
        const f = win.filterKind;
        return win.service.entries.filter(e => {
            if (f === "pinned")
                return false;
            if (f === "images" && !e.isImage)
                return false;
            if (f === "links" && e.kind !== "url")
                return false;
            if (f === "code" && e.kind !== "code")
                return false;
            if (f === "text" && (e.isImage || e.kind !== "text"))
                return false;
            return win.matchQuery(e.preview);
        });
    }

    function pinMatches(): var {
        if (!win.pins)
            return [];
        return win.pins.pins.filter(p => {
            const hay = p.kind === "image" ? ((p.title || "") + " " + (p.sub || "")) : (p.label || "");
            return win.matchQuery(hay);
        });
    }

    function kindCount(k: string): int {
        if (!win.service)
            return 0;
        if (k === "all")
            return win.service.entries.length;
        if (k === "pinned")
            return win.pins ? win.pins.pins.length : 0;
        return win.service.entries.filter(e => {
            if (k === "images")
                return e.isImage;
            if (k === "links")
                return e.kind === "url";
            if (k === "code")
                return e.kind === "code";
            return !e.isImage && e.kind === "text";
        }).length;
    }

    function copyFirst(): void {
        if (win.filterKind === "pinned") {
            const p = win.pinMatches();
            if (p.length > 0) {
                win.pins.copyPin(p[0]);
                win.requestClose();
            }
            return;
        }
        const h = win.histMatches();
        if (h.length > 0) {
            win.service.copyEntry(h[0]);
            win.requestClose();
            return;
        }
        if (win.filterKind === "all") {
            const p = win.pinMatches();
            if (p.length > 0) {
                win.pins.copyPin(p[0]);
                win.requestClose();
            }
        }
    }

    function pinEntry(e: var): void {
        if (!e || !win.pins)
            return;
        if (e.isImage) {
            const dest = win.pins.dir + "/pin-" + Date.now() + "-" + e.cid + ".bin";
            win.service.exportImage(e, dest, (arg, res) => {
                if (res === "OK")
                    win.pins.addImage(arg.mime, arg.title, arg.sub, dest);
            });
        } else {
            win.service.decodeText(e, (arg, text) => {
                win.pins.addText(arg.title || arg.preview, text);
            });
        }
    }

    function unpin(p: var): void {
        if (!win.pins)
            return;
        for (let i = 0; i < win.pins.pins.length; i++) {
            if (win.pins.pins[i].created === p.created) {
                win.pins.removeAt(i);
                return;
            }
        }
    }

    // ---- Preview overlay ----
    function previewIsImage(): bool {
        const t = win.previewTarget;
        if (!t)
            return false;
        return t.source === "pin" ? t.pin.kind === "image" : t.entry.isImage;
    }

    function previewIsPin(): bool {
        return win.previewTarget && win.previewTarget.source === "pin";
    }

    function openPreviewHistory(e: var): void {
        const tok = {
            source: "history",
            entry: e
        };
        win.previewTarget = tok;
        win.previewImage = "";
        win.previewText = "";
        win.previewMeta = "";
        win.previewLoading = true;
        if (e.isImage) {
            const ext = e.mime === "image/jpeg" ? "jpg" : "png";
            const dest = Quickshell.env("HOME") + "/.cache/clipboard-panel/full-" + e.cid + "." + ext;
            win.service.exportImage(e, dest, (arg, res) => {
                if (win.previewTarget !== tok)
                    return;
                if (res === "OK") {
                    win.previewImage = dest;
                    win.previewMeta = arg.sub || arg.mime;
                } else {
                    win.previewMeta = "Could not load image";
                }
                win.previewLoading = false;
            });
        } else {
            win.service.decodeText(e, (arg, text) => {
                if (win.previewTarget !== tok)
                    return;
                win.previewText = text;
                const label = arg.kind === "url" ? "Link" : arg.kind === "code" ? "Code" : "Text";
                win.previewMeta = label + " · " + text.length + " chars";
                win.previewLoading = false;
            });
        }
    }

    function openPreviewPin(p: var): void {
        win.previewTarget = {
            source: "pin",
            pin: p
        };
        win.previewImage = "";
        win.previewText = "";
        win.previewLoading = false;
        if (p.kind === "image") {
            win.previewImage = p.path;
            win.previewMeta = p.sub || p.mime || "Image";
        } else {
            let body = "";
            try {
                body = decodeURIComponent(escape(Qt.atob(p.b64 || "")));
            } catch (err) {
                body = "(could not decode pinned text)";
            }
            win.previewText = body;
            win.previewMeta = "Pinned text · " + body.length + " chars";
        }
    }

    function previewBack(): void {
        win.previewTarget = null;
    }

    function previewCopy(): void {
        const t = win.previewTarget;
        if (!t)
            return;
        if (t.source === "pin")
            win.pins.copyPin(t.pin);
        else
            win.service.copyEntry(t.entry);
        win.previewTarget = null;
        win.requestClose();
    }

    function previewPinToggle(): void {
        const t = win.previewTarget;
        if (!t)
            return;
        if (t.source === "pin") {
            win.unpin(t.pin);
        } else {
            win.pinEntry(t.entry);
        }
        win.previewTarget = null;
    }

    function previewDelete(): void {
        const t = win.previewTarget;
        if (!t)
            return;
        if (t.source === "pin") {
            win.unpin(t.pin);
        } else {
            win.service.deleteEntry(t.entry);
        }
        win.previewTarget = null;
    }

    Rectangle {
        id: bg

        anchors.fill: parent
        color: win.theme.surfaceContainerLow
        radius: 20

        // Square off the right edge so the panel reads as connected to
        // the screen (left corners stay rounded). Same color: no seam.
        Rectangle {
            width: 20
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            color: win.theme.surfaceContainerLow
        }

        // Slide driven by the spring above (no fade — the window edge
        // clips the panel while it travels in from off-screen)
        x: (1 - win.openProg) * win.implicitWidth
        opacity: 1

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header
            Item {
                width: parent.width
                height: 40

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clipboard"
                    color: win.theme.ink
                    font.family: win.uiFont
                    renderType: Text.NativeRendering
                    font.pixelSize: 20
                    font.bold: true
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: refreshHover.containsMouse ? win.theme.surfaceContainerHigh : "transparent"

                        Behavior on color {
                            NumberAnimation {
                                duration: 200
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "refresh"
                            font.family: win.iconFont
                            font.pixelSize: 22
                            renderType: Text.NativeRendering
                            color: win.theme.primary
                            opacity: (win.service && win.service.loading) ? 0.5 : (refreshHover.containsMouse ? 1 : 0.8)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                }
                            }
                        }

                        MouseArea {
                            id: refreshHover

                            anchors.fill: parent
                            hoverEnabled: win.hoverLive
                            enabled: !(win.service && win.service.loading)
                            onClicked: win.service.refresh()
                        }
                    }

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: closeHover.containsMouse ? win.theme.surfaceContainerHigh : "transparent"

                        Behavior on color {
                            NumberAnimation {
                                duration: 200
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            font.family: win.iconFont
                            font.pixelSize: 22
                            renderType: Text.NativeRendering
                            color: win.theme.inkDim
                            opacity: closeHover.containsMouse ? 1 : 0.8

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                }
                            }
                        }

                        MouseArea {
                            id: closeHover

                            anchors.fill: parent
                            hoverEnabled: win.hoverLive
                            onClicked: win.requestClose()
                        }
                    }
                }
            }

            // Search (pill with icon + accent focus ring)
            Rectangle {
                width: parent.width
                height: 54
                radius: 27
                color: win.theme.surfaceContainer
                border.color: win.theme.primary
                border.width: searchInput.activeFocus ? 1 : 0

                Behavior on border.width {
                    NumberAnimation {
                        duration: 200
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "search"
                    font.family: win.iconFont
                    font.pixelSize: 24
                    renderType: Text.NativeRendering
                    color: searchInput.activeFocus ? win.theme.primary : win.theme.inkDim

                    Behavior on color {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }

                TextInput {
                    id: searchInput

                    anchors.fill: parent
                    anchors.leftMargin: 54
                    anchors.rightMargin: 16
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: win.theme.ink
                    font.family: win.uiFont
                    renderType: TextInput.NativeRendering
                    font.pixelSize: 19
                    text: win.query
                    onTextChanged: win.query = text
                    Keys.onReturnPressed: win.copyFirst()
                    Keys.onEnterPressed: win.copyFirst()
                    // Window-level Shortcut doesn't fire on layer-shell;
                    // handle Esc where focus actually lives.
                    Keys.onEscapePressed: {
                        if (win.previewTarget)
                            win.previewBack();
                        else
                            win.requestClose();
                    }
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 54
                    anchors.rightMargin: 16
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    text: "Search clipboard…"
                    color: win.theme.inkDim
                    font.family: win.uiFont
                    renderType: Text.NativeRendering
                    font.pixelSize: 19
                    visible: searchInput.displayText === ""
                }
            }

            // Category chips
            Flickable {
                width: parent.width
                height: 42
                contentWidth: chipRow.width
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: chipRow

                    height: 42
                    spacing: 8

                    Repeater {
                        model: [{
                            k: "all",
                            t: "All"
                        }, {
                            k: "text",
                            t: "Text"
                        }, {
                            k: "images",
                            t: "Images"
                        }, {
                            k: "links",
                            t: "Links"
                        }, {
                            k: "code",
                            t: "Code"
                        }, {
                            k: "pinned",
                            t: "Pinned"
                        }]

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool selected: win.filterKind === modelData.k

                            height: 40
                            width: chipLabel.width + 28
                            radius: 20
                            color: selected ? win.theme.primaryContainer : win.theme.surfaceContainerHighest
                            border.width: 0

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: win.theme.ink
                                opacity: !parent.selected && chipHover.containsMouse ? 0.08 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 160
                                    }
                                }
                            }

                            Text {
                                id: chipLabel

                                anchors.centerIn: parent
                                text: modelData.t + " · " + win.kindCount(modelData.k)
                                font.family: win.uiFont
                                font.pixelSize: 16
                                renderType: Text.NativeRendering
                                color: parent.selected ? win.theme.primaryContainerText : win.theme.ink
                            }

                            MouseArea {
                                id: chipHover

                                anchors.fill: parent
                                hoverEnabled: win.hoverLive
                                onClicked: win.filterKind = modelData.k
                            }
                        }
                    }
                }
            }

            // Pinned section
            Text {
                text: "Pinned (" + win.pinMatches().length + ")"
                color: win.theme.inkDim
                font.family: win.uiFont
                renderType: Text.NativeRendering
                font.pixelSize: 20
                visible: win.filterKind === "all" || win.filterKind === "pinned"
            }

            ListView {
                id: pinList

                width: parent.width
                height: win.filterKind === "pinned" ? parent.height - y - 56 : Math.min(366, count * 122)
                visible: count > 0 && (win.filterKind === "all" || win.filterKind === "pinned")
                clip: true
                spacing: 6
                cacheBuffer: 120
                reuseItems: true
                model: win.pinMatches()

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    interactive: true
                    width: 8
                    opacity: hovered || pressed ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }

                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 4
                        color: win.theme.inkDim
                        opacity: 0.65
                    }

                    background: Rectangle {
                        color: "transparent"
                    }
                }

                delegate: ClipRow {
                    required property var modelData

                    width: pinList.width
                    uiFont: win.uiFont
                    iconFont: win.iconFont
                    theme: win.theme
                    uiActive: win.panelOpen && win.previewTarget === null
                    hoverLive: win.hoverLive
                    rowKey: "p" + modelData.created
                    hoverKey: win.hoverKey
                    onHoverPart: part => {
                        const k = "p" + modelData.created;
                        if (part === "") {
                            if (win.hoverKey === k || win.hoverKey.indexOf(k + ":") === 0)
                                win.hoverKey = "";
                        } else {
                            win.hoverKey = k + ":" + part;
                        }
                    }
                    entry: modelData.kind === "image" ? {
                        kind: "image",
                        title: modelData.title,
                        sub: modelData.sub,
                        isImage: true,
                        thumb: modelData.path
                    } : {
                        kind: "text",
                        title: modelData.label,
                        sub: "",
                        isImage: false,
                        thumb: ""
                    }
                    pinned: true
                    onClicked: {
                        win.pins.copyPin(modelData);
                        win.requestClose();
                    }
                    onDoubleClicked: {
                        win.pins.copyPin(modelData);
                        win.requestClose();
                    }
                    onPreviewClicked: win.openPreviewPin(modelData)
                    onPinClicked: win.unpin(modelData)
                    onDelClicked: win.unpin(modelData)
                }
            }

            Text {
                text: "No pinned items — hover a row and hit ☆"
                color: win.theme.inkDim
                font.family: win.uiFont
                renderType: Text.NativeRendering
                font.pixelSize: 16
                visible: win.pinMatches().length === 0 && (win.filterKind === "all" || win.filterKind === "pinned")
            }

            // History section
            Text {
                text: "History (" + win.histMatches().length + ")"
                color: win.theme.inkDim
                font.family: win.uiFont
                renderType: Text.NativeRendering
                font.pixelSize: 20
                visible: win.filterKind !== "pinned"
            }

            ListView {
                id: histList

                width: parent.width
                height: parent.height - y - 56
                clip: true
                spacing: 6
                visible: win.filterKind !== "pinned"
                cacheBuffer: 240
                reuseItems: true
                model: win.histMatches()

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    interactive: true
                    width: 8
                    opacity: hovered || pressed ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }

                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 4
                        color: win.theme.inkDim
                        opacity: 0.65
                    }

                    background: Rectangle {
                        color: "transparent"
                    }
                }

                delegate: ClipRow {
                    required property var modelData

                    width: histList.width
                    uiFont: win.uiFont
                    iconFont: win.iconFont
                    theme: win.theme
                    uiActive: win.panelOpen && win.previewTarget === null
                    hoverLive: win.hoverLive
                    rowKey: "h" + modelData.cid
                    hoverKey: win.hoverKey
                    onHoverPart: part => {
                        const k = "h" + modelData.cid;
                        if (part === "") {
                            if (win.hoverKey === k || win.hoverKey.indexOf(k + ":") === 0)
                                win.hoverKey = "";
                        } else {
                            win.hoverKey = k + ":" + part;
                        }
                    }
                    entry: modelData
                    pinned: false
                    onClicked: {
                        win.service.copyEntry(modelData);
                        win.requestClose();
                    }
                    onDoubleClicked: {
                        win.service.copyEntry(modelData);
                        win.requestClose();
                    }
                    onPreviewClicked: win.openPreviewHistory(modelData)
                    onPinClicked: win.pinEntry(modelData)
                    onDelClicked: win.service.deleteEntry(modelData)
                }
            }

            // Bottom action bar (mirrors the sidebar's bottom action button)
            Item {
                width: parent.width
                height: 44

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: clearRow.width + 28
                    height: 38
                    radius: 19
                    color: clearHover.containsMouse ? win.theme.surfaceContainerHigh : "transparent"

                    Behavior on color {
                        NumberAnimation {
                            duration: 200
                        }
                    }

                    Row {
                        id: clearRow

                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "delete_sweep"
                            font.family: win.iconFont
                            font.pixelSize: 22
                            renderType: Text.NativeRendering
                            color: win.theme.inkDim
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Clear history"
                            color: win.theme.inkDim
                            font.family: win.uiFont
                            renderType: Text.NativeRendering
                            font.pixelSize: 16
                        }
                    }

                    MouseArea {
                        id: clearHover

                        anchors.fill: parent
                        hoverEnabled: win.hoverLive
                        onClicked: win.service.wipeHistory()
                    }
                }
            }
        }

        // Preview overlay (Edge-Drop flyout): full content + actions
        Item {
            anchors.fill: parent
            visible: win.previewTarget !== null

            Rectangle {
                anchors.fill: parent
                color: win.theme.surfaceContainerLow
                radius: 20

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Item {
                        width: parent.width
                        height: 40

                        Rectangle {
                            width: 40
                            height: 40
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 20
                            color: backHover.containsMouse ? win.theme.surfaceContainerHigh : "transparent"

                            Behavior on color {
                                NumberAnimation {
                                    duration: 200
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "chevron_left"
                                font.family: win.iconFont
                                font.pixelSize: 26
                                renderType: Text.NativeRendering
                                color: win.theme.ink
                            }

                            MouseArea {
                                id: backHover

                                anchors.fill: parent
                                hoverEnabled: win.hoverLive
                                onClicked: win.previewBack()
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 40
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Preview"
                            color: win.theme.ink
                            font.family: win.uiFont
                            renderType: Text.NativeRendering
                            font.pixelSize: 19
                            font.bold: true
                        }
                    }

                    Text {
                        width: parent.width
                        text: win.previewLoading ? "Loading…" : win.previewMeta
                        color: win.theme.inkDim
                        font.family: win.uiFont
                        renderType: Text.NativeRendering
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }

                    Item {
                        width: parent.width
                        height: parent.height - y - 60

                        Flickable {
                            anchors.fill: parent
                            visible: !win.previewIsImage() && !win.previewLoading
                            clip: true
                            contentWidth: width
                            contentHeight: previewBody.height
                            boundsBehavior: Flickable.StopAtBounds

                            Text {
                                id: previewBody

                                width: parent.width
                                text: win.previewText
                                color: win.theme.ink
                                font.family: win.uiFont
                                renderType: Text.NativeRendering
                                font.pixelSize: 24
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                            }
                        }

                        Image {
                            anchors.fill: parent
                            visible: win.previewIsImage() && win.previewImage !== "" && !win.previewLoading
                            source: visible ? "file://" + win.previewImage : ""
                            asynchronous: true
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                    }

                    Row {
                        width: parent.width
                        height: 48
                        spacing: 10

                        Rectangle {
                            width: copyLabel.width + 32
                            height: 46
                            radius: 23
                            color: copyHover.containsMouse ? win.theme.primary : win.theme.primaryContainer

                            Behavior on color {
                                NumberAnimation {
                                    duration: 200
                                }
                            }

                            Text {
                                id: copyLabel

                                anchors.centerIn: parent
                                text: "Copy"
                                font.family: win.uiFont
                                font.pixelSize: 24
                                renderType: Text.NativeRendering
                                color: copyHover.containsMouse ? win.theme.surfaceContainerLow : win.theme.primary
                            }

                            MouseArea {
                                id: copyHover

                                anchors.fill: parent
                                hoverEnabled: win.hoverLive
                                onClicked: win.previewCopy()
                            }
                        }

                        Rectangle {
                            width: pinLabel.width + 32
                            height: 46
                            radius: 23
                            color: pinBtnHover.containsMouse ? win.theme.surfaceContainerHigh : "transparent"

                            Behavior on color {
                                NumberAnimation {
                                    duration: 200
                                }
                            }

                            Text {
                                id: pinLabel

                                anchors.centerIn: parent
                                text: win.previewIsPin() ? "Unpin" : "Pin"
                                font.family: win.uiFont
                                font.pixelSize: 24
                                renderType: Text.NativeRendering
                                color: win.theme.inkDim
                            }

                            MouseArea {
                                id: pinBtnHover

                                anchors.fill: parent
                                hoverEnabled: win.hoverLive
                                onClicked: win.previewPinToggle()
                            }
                        }

                        Rectangle {
                            width: delLabel.width + 32
                            height: 46
                            radius: 23
                            color: delBtnHover.containsMouse ? win.theme.surfaceContainerHigh : "transparent"

                            Behavior on color {
                                NumberAnimation {
                                    duration: 200
                                }
                            }

                            Text {
                                id: delLabel

                                anchors.centerIn: parent
                                text: "Delete"
                                font.family: win.uiFont
                                font.pixelSize: 24
                                renderType: Text.NativeRendering
                                color: win.theme.inkDim
                            }

                            MouseArea {
                                id: delBtnHover

                                anchors.fill: parent
                                hoverEnabled: win.hoverLive
                                onClicked: win.previewDelete()
                            }
                        }
                    }
                }
            }
        }

        IpcHandler {
            target: "clipboardUi"

            function setFilter(kind: string): void {
                if (["all", "text", "images", "links", "code", "pinned"].includes(kind)) {
                    win.query = "";
                    win.filterKind = kind;
                }
            }

            function previewTop(): void {
                const h = win.histMatches();
                if (h.length > 0)
                    win.openPreviewHistory(h[0]);
            }
        }
    }
}
