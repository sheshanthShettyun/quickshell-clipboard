pragma ComponentBehavior: Bound

import QtQuick
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
    margins.top: 12
    margins.bottom: 12
    margins.right: 12
    implicitWidth: 400
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    color: "transparent"

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
    // UI font, matches the Caelestia shell bars/panels — change here to restyle
    property string uiFont: "Rubik"
    // Material Symbols, same icon language as the Caelestia shell
    property string iconFont: "Material Symbols Rounded"

    onVisibleChanged: {
        if (visible) {
            win.query = "";
            win.filterKind = "all";
            win.previewTarget = null;
            searchInput.forceActiveFocus();
        } else {
            win.hoverKey = "";
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

        // Slide-and-fade entrance, mirroring the sidebar drawer motion
        x: win.panelOpen ? 0 : 40
        opacity: win.panelOpen ? 1 : 0

        Behavior on x {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header
            Item {
                width: parent.width
                height: 32

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clipboard"
                    color: win.theme.ink
                    font.family: win.uiFont
                    renderType: Text.NativeRendering
                    font.pixelSize: 16
                    font.bold: true
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: refreshHover.containsMouse ? win.theme.surfaceContainerHigh : "transparent"

                        Behavior on color {
                            NumberAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "refresh"
                            font.family: win.iconFont
                            font.pixelSize: 19
                            renderType: Text.NativeRendering
                            color: win.theme.primary
                            opacity: (win.service && win.service.loading) ? 0.5 : (refreshHover.containsMouse ? 1 : 0.8)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }

                        MouseArea {
                            id: refreshHover

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !(win.service && win.service.loading)
                            onClicked: win.service.refresh()
                        }
                    }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: closeHover.containsMouse ? win.theme.surfaceContainerHigh : "transparent"

                        Behavior on color {
                            NumberAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            font.family: win.iconFont
                            font.pixelSize: 19
                            renderType: Text.NativeRendering
                            color: win.theme.inkDim
                            opacity: closeHover.containsMouse ? 1 : 0.8

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }

                        MouseArea {
                            id: closeHover

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: win.requestClose()
                        }
                    }
                }
            }

            // Search (pill with icon + accent focus ring)
            Rectangle {
                width: parent.width
                height: 42
                radius: 21
                color: win.theme.surfaceContainer
                border.color: win.theme.primary
                border.width: searchInput.activeFocus ? 1 : 0

                Behavior on border.width {
                    NumberAnimation {
                        duration: 120
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    text: "search"
                    font.family: win.iconFont
                    font.pixelSize: 20
                    renderType: Text.NativeRendering
                    color: searchInput.activeFocus ? win.theme.primary : win.theme.inkDim

                    Behavior on color {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                }

                TextInput {
                    id: searchInput

                    anchors.fill: parent
                    anchors.leftMargin: 42
                    anchors.rightMargin: 14
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: win.theme.ink
                    font.family: win.uiFont
                    renderType: TextInput.NativeRendering
                    font.pixelSize: 14
                    text: win.query
                    onTextChanged: win.query = text
                    Keys.onReturnPressed: win.copyFirst()
                    Keys.onEnterPressed: win.copyFirst()
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 42
                    anchors.rightMargin: 14
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    text: "Search clipboard…"
                    color: win.theme.inkDim
                    font.family: win.uiFont
                    renderType: Text.NativeRendering
                    font.pixelSize: 14
                    visible: searchInput.displayText === ""
                }
            }

            // Category chips
            Flickable {
                width: parent.width
                height: 32
                contentWidth: chipRow.width
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: chipRow

                    height: 32
                    spacing: 6

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

                            height: 30
                            width: chipLabel.width + 24
                            radius: 15
                            color: selected ? win.theme.primaryContainer : (chipHover.containsMouse ? win.theme.surfaceContainerHigh : "transparent")

                            Behavior on color {
                                NumberAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                id: chipLabel

                                anchors.centerIn: parent
                                text: modelData.t + " · " + win.kindCount(modelData.k)
                                font.family: win.uiFont
                                font.pixelSize: 12
                                renderType: Text.NativeRendering
                                color: parent.selected ? win.theme.primary : win.theme.inkDim
                            }

                            MouseArea {
                                id: chipHover

                                anchors.fill: parent
                                hoverEnabled: true
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
                font.pixelSize: 15
                visible: win.filterKind === "all" || win.filterKind === "pinned"
            }

            ListView {
                id: pinList

                width: parent.width
                height: win.filterKind === "pinned" ? parent.height - y - 48 : Math.min(282, count * 94)
                visible: count > 0 && (win.filterKind === "all" || win.filterKind === "pinned")
                clip: true
                spacing: 6
                model: win.pinMatches()

                delegate: ClipRow {
                    required property var modelData

                    width: pinList.width
                    uiFont: win.uiFont
                    iconFont: win.iconFont
                    theme: win.theme
                    highlighted: win.hoverKey === "p" + modelData.created
                    onHovered: on => {
                        const k = "p" + modelData.created;
                        win.hoverKey = on ? k : (win.hoverKey === k ? "" : win.hoverKey);
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
                    onClicked: win.openPreviewPin(modelData)
                    onDoubleClicked: {
                        win.pins.copyPin(modelData);
                        win.requestClose();
                    }
                    onPinClicked: win.unpin(modelData)
                    onDelClicked: win.unpin(modelData)
                }
            }

            Text {
                text: "No pinned items — hover a row and hit ☆"
                color: win.theme.inkDim
                font.family: win.uiFont
                renderType: Text.NativeRendering
                font.pixelSize: 12
                visible: win.pinMatches().length === 0 && (win.filterKind === "all" || win.filterKind === "pinned")
            }

            // History section
            Text {
                text: "History (" + win.histMatches().length + ")"
                color: win.theme.inkDim
                font.family: win.uiFont
                renderType: Text.NativeRendering
                font.pixelSize: 15
                visible: win.filterKind !== "pinned"
            }

            ListView {
                id: histList

                width: parent.width
                height: parent.height - y - 48
                clip: true
                spacing: 6
                visible: win.filterKind !== "pinned"
                model: win.histMatches()

                delegate: ClipRow {
                    required property var modelData

                    width: histList.width
                    uiFont: win.uiFont
                    iconFont: win.iconFont
                    theme: win.theme
                    highlighted: win.hoverKey === "h" + modelData.cid
                    onHovered: on => {
                        const k = "h" + modelData.cid;
                        win.hoverKey = on ? k : (win.hoverKey === k ? "" : win.hoverKey);
                    }
                    entry: modelData
                    pinned: false
                    onClicked: win.openPreviewHistory(modelData)
                    onDoubleClicked: {
                        win.service.copyEntry(modelData);
                        win.requestClose();
                    }
                    onPinClicked: win.pinEntry(modelData)
                    onDelClicked: win.service.deleteEntry(modelData)
                }
            }

            // Bottom action bar (mirrors the sidebar's bottom action button)
            Item {
                width: parent.width
                height: 36

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: clearRow.width + 24
                    height: 30
                    radius: 15
                    color: clearHover.containsMouse ? win.theme.surfaceContainerHigh : "transparent"

                    Behavior on color {
                        NumberAnimation {
                            duration: 120
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
                            font.pixelSize: 17
                            renderType: Text.NativeRendering
                            color: win.theme.inkDim
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Clear history"
                            color: win.theme.inkDim
                            font.family: win.uiFont
                            renderType: Text.NativeRendering
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: clearHover

                        anchors.fill: parent
                        hoverEnabled: true
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
                        height: 32

                        Rectangle {
                            width: 32
                            height: 32
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 16
                            color: backHover.containsMouse ? win.theme.surfaceContainerHigh : "transparent"

                            Behavior on color {
                                NumberAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "chevron_left"
                                font.family: win.iconFont
                                font.pixelSize: 22
                                renderType: Text.NativeRendering
                                color: win.theme.ink
                            }

                            MouseArea {
                                id: backHover

                                anchors.fill: parent
                                hoverEnabled: true
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
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }

                    Text {
                        width: parent.width
                        text: win.previewLoading ? "Loading…" : win.previewMeta
                        color: win.theme.inkDim
                        font.family: win.uiFont
                        renderType: Text.NativeRendering
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Item {
                        width: parent.width
                        height: parent.height - y - 52

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
                                font.pixelSize: 13
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
                        height: 40
                        spacing: 8

                        Rectangle {
                            width: copyLabel.width + 28
                            height: 36
                            radius: 18
                            color: copyHover.containsMouse ? win.theme.primary : win.theme.primaryContainer

                            Behavior on color {
                                NumberAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                id: copyLabel

                                anchors.centerIn: parent
                                text: "Copy"
                                font.family: win.uiFont
                                font.pixelSize: 13
                                renderType: Text.NativeRendering
                                color: copyHover.containsMouse ? win.theme.surfaceContainerLow : win.theme.primary
                            }

                            MouseArea {
                                id: copyHover

                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: win.previewCopy()
                            }
                        }

                        Rectangle {
                            width: pinLabel.width + 28
                            height: 36
                            radius: 18
                            color: pinBtnHover.containsMouse ? win.theme.surfaceContainerHigh : "transparent"

                            Behavior on color {
                                NumberAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                id: pinLabel

                                anchors.centerIn: parent
                                text: win.previewIsPin() ? "Unpin" : "Pin"
                                font.family: win.uiFont
                                font.pixelSize: 13
                                renderType: Text.NativeRendering
                                color: win.theme.inkDim
                            }

                            MouseArea {
                                id: pinBtnHover

                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: win.previewPinToggle()
                            }
                        }

                        Rectangle {
                            width: delLabel.width + 28
                            height: 36
                            radius: 18
                            color: delBtnHover.containsMouse ? win.theme.surfaceContainerHigh : "transparent"

                            Behavior on color {
                                NumberAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                id: delLabel

                                anchors.centerIn: parent
                                text: "Delete"
                                font.family: win.uiFont
                                font.pixelSize: 13
                                renderType: Text.NativeRendering
                                color: win.theme.inkDim
                            }

                            MouseArea {
                                id: delBtnHover

                                anchors.fill: parent
                                hoverEnabled: true
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
