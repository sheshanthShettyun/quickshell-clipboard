pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services

// Clipboard drawer content: search, filter chips, pinned + history,
// preview overlay. Native Caelestia language throughout.
Item {
    id: root

    required property ScreenState screenState

    property string query: ""
    property string filterKind: "all"
    property var previewTarget: null
    property string previewText: ""
    property string previewImage: ""
    property string previewMeta: ""
    property bool previewLoading: false
    property string hoverKey: ""
    property bool hoverLive: true

    ClipService {
        id: service
    }

    Pins {
        id: pins
    }

    onVisibleChanged: {
        if (visible) {
            root.query = "";
            root.filterKind = "all";
            root.previewTarget = null;
            root.hoverLive = true;
            service.refresh();
            search.forceActiveFocus();
        } else {
            root.hoverKey = "";
            root.hoverLive = false;
            root.previewTarget = null;
        }
    }

    Connections {
        target: service

        function onLoadingChanged() {
            if (service.loading)
                root.hoverKey = "";
        }
    }

    function matchQuery(text: string): bool {
        if (root.query === "")
            return true;
        return text.toLowerCase().includes(root.query.toLowerCase());
    }

    function histMatches(): var {
        const f = root.filterKind;
        return service.entries.filter(e => {
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
            return root.matchQuery(e.preview);
        });
    }

    function pinMatches(): var {
        return pins.pins.filter(p => {
            const hay = p.kind === "image" ? ((p.title || "") + " " + (p.sub || "")) : (p.label || "");
            return root.matchQuery(hay);
        });
    }

    function kindCount(k: string): int {
        if (k === "all")
            return service.entries.length;
        if (k === "pinned")
            return pins.pins.length;
        return service.entries.filter(e => {
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
        if (root.filterKind === "pinned") {
            const p = root.pinMatches();
            if (p.length > 0) {
                pins.copyPin(p[0]);
                root.screenState.clipboard = false;
            }
            return;
        }
        const h = root.histMatches();
        if (h.length > 0) {
            service.copyEntry(h[0]);
            root.screenState.clipboard = false;
            return;
        }
        if (root.filterKind === "all") {
            const p = root.pinMatches();
            if (p.length > 0) {
                pins.copyPin(p[0]);
                root.screenState.clipboard = false;
            }
        }
    }

    function pinEntry(e: var): void {
        if (!e)
            return;
        if (e.isImage) {
            const dest = pins.dir + "/pin-" + Date.now() + "-" + e.cid + ".bin";
            service.exportImage(e, dest, (arg, res) => {
                if (res === "OK")
                    pins.addImage(arg.mime, arg.title, arg.sub, dest);
            });
        } else {
            service.decodeText(e, (arg, text) => {
                pins.addText(arg.title || arg.preview, text);
            });
        }
    }

    function unpin(p: var): void {
        for (let i = 0; i < pins.pins.length; i++) {
            if (pins.pins[i].created === p.created) {
                pins.removeAt(i);
                return;
            }
        }
    }

    function previewIsImage(): bool {
        const t = root.previewTarget;
        if (!t)
            return false;
        return t.source === "pin" ? t.pin.kind === "image" : t.entry.isImage;
    }

    function previewIsPin(): bool {
        return root.previewTarget && root.previewTarget.source === "pin";
    }

    function openPreviewHistory(e: var): void {
        const tok = {
            source: "history",
            entry: e
        };
        root.previewTarget = tok;
        root.previewImage = "";
        root.previewText = "";
        root.previewMeta = "";
        root.previewLoading = true;
        if (e.isImage) {
            const ext = e.mime === "image/jpeg" ? "jpg" : "png";
            const dest = Quickshell.env("HOME") + "/.cache/clipboard-panel/full-" + e.cid + "." + ext;
            service.exportImage(e, dest, (arg, res) => {
                if (root.previewTarget !== tok)
                    return;
                if (res === "OK") {
                    root.previewImage = dest;
                    root.previewMeta = arg.sub || arg.mime;
                } else {
                    root.previewMeta = "Could not load image";
                }
                root.previewLoading = false;
            });
        } else {
            service.decodeText(e, (arg, text) => {
                if (root.previewTarget !== tok)
                    return;
                root.previewText = text;
                const label = arg.kind === "url" ? "Link" : arg.kind === "code" ? "Code" : "Text";
                root.previewMeta = label + " · " + text.length + " chars";
                root.previewLoading = false;
            });
        }
    }

    function openPreviewPin(p: var): void {
        root.previewTarget = {
            source: "pin",
            pin: p
        };
        root.previewImage = "";
        root.previewText = "";
        root.previewLoading = false;
        if (p.kind === "image") {
            root.previewImage = p.path;
            root.previewMeta = p.sub || p.mime || "Image";
        } else {
            let body = "";
            try {
                body = decodeURIComponent(escape(Qt.atob(p.b64 || "")));
            } catch (err) {
                body = "(could not decode pinned text)";
            }
            root.previewText = body;
            root.previewMeta = "Pinned text · " + body.length + " chars";
        }
    }

    function previewBack(): void {
        root.previewTarget = null;
    }

    function previewCopy(): void {
        const t = root.previewTarget;
        if (!t)
            return;
        if (t.source === "pin")
            pins.copyPin(t.pin);
        else
            service.copyEntry(t.entry);
        root.previewTarget = null;
        root.screenState.clipboard = false;
    }

    function previewPinToggle(): void {
        const t = root.previewTarget;
        if (!t)
            return;
        if (t.source === "pin")
            root.unpin(t.pin);
        else
            root.pinEntry(t.entry);
        root.previewTarget = null;
    }

    function previewDelete(): void {
        const t = root.previewTarget;
        if (!t)
            return;
        if (t.source === "pin")
            root.unpin(t.pin);
        else
            service.deleteEntry(t.entry);
        root.previewTarget = null;
    }

    function reportHover(key: string, part: string): void {
        if (part === "") {
            if (root.hoverKey === key || root.hoverKey.indexOf(key + ":") === 0)
                root.hoverKey = "";
        } else {
            root.hoverKey = key + ":" + part;
        }
    }

    function rowKeyFor(m: var): string {
        return m.pinned ? "p" + m.ref.created : "h" + m.ref.cid;
    }

    function activateEntry(m: var): void {
        if (m.pinned) {
            pins.copyPin(m.ref);
        } else {
            service.copyEntry(m.ref);
        }
        root.screenState.clipboard = false;
    }

    function openPreview(m: var): void {
        if (m.pinned)
            root.openPreviewPin(m.ref);
        else
            root.openPreviewHistory(m.ref);
    }

    function togglePin(m: var): void {
        if (m.pinned)
            root.unpin(m.ref);
        else
            root.pinEntry(m.ref);
    }

    function deleteEntry(m: var): void {
        if (m.pinned)
            root.unpin(m.ref);
        else
            service.deleteEntry(m.ref);
    }

    function closeDrawer(): void {
        root.screenState.clipboard = false;
    }

    function pinItems(): var {
        return root.pinMatches().map(p => ({
            key: "p" + p.created,
            entry: p.kind === "image" ? {
                kind: "image",
                title: p.title,
                sub: p.sub,
                isImage: true,
                thumb: p.path
            } : {
                kind: "text",
                title: p.label,
                sub: "",
                isImage: false,
                thumb: ""
            },
            pinned: true,
            ref: p
        }));
    }

    function histItems(): var {
        return root.histMatches().map(e => ({
            key: "h" + e.cid,
            entry: e,
            pinned: false,
            ref: e
        }));
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        spacing: Tokens.spacing.medium

        Item {
            Layout.fillWidth: true
            implicitHeight: 40

            StyledText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Clipboard"
                font: Tokens.font.title.small
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.spacing.extraSmall

                IconButton {
                    icon: "refresh"
                    font: Tokens.font.icon.small
                    onClicked: service.refresh()
                }

                IconButton {
                    icon: "close"
                    font: Tokens.font.icon.small
                    onClicked: root.closeDrawer()
                }
            }
        }

        SearchBar {
            id: search

            Layout.fillWidth: true
            placeholderText: "Search clipboard…"
            onTextChanged: root.query = text
            Keys.onReturnPressed: root.copyFirst()
            Keys.onEnterPressed: root.copyFirst()
            Keys.onEscapePressed: {
                if (root.previewTarget)
                    root.previewBack();
                else
                    root.closeDrawer();
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            contentWidth: chipRow.width
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Item {
                id: chipContent

                width: chipRow.width
                height: 42

                function activeChip(): var {
                    for (let i = 0; i < chipRepeater.count; i++) {
                        const item = chipRepeater.itemAt(i);
                        if (item && item.selected)
                            return item;
                    }
                    return null;
                }

                    Rectangle {
                        id: activePill

                        readonly property var targetChip: chipContent.activeChip()

                        x: targetChip ? targetChip.x : 0
                        y: targetChip ? targetChip.y : 0
                        width: targetChip ? targetChip.width : 0
                        height: 40
                        radius: 20
                        color: Colours.tPalette.m3primaryContainer
                        visible: width > 0
                        z: 0

                        Behavior on x {
                        SpringAnimation {
                            spring: 4.6
                            damping: 0.42
                            epsilon: 0.25
                        }
                    }

                    Behavior on width {
                        SpringAnimation {
                            spring: 4.6
                            damping: 0.42
                            epsilon: 0.25
                        }
                    }
                }

                Row {
                    id: chipRow

                    height: 42
                    spacing: Tokens.spacing.small
                    z: 1

                    Repeater {
                        id: chipRepeater

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

                        delegate: Item {
                            required property var modelData

                            readonly property bool selected: root.filterKind === modelData.k
                            readonly property bool hovered: chipMouse.containsMouse

                            height: 40
                            width: chipLabel.width + Tokens.padding.large * 2

                            StyledRect {
                                anchors.fill: parent
                                radius: Tokens.rounding.full
                                color: Colours.tPalette.m3surfaceContainerHighest
                                opacity: parent.selected ? 0 : 1
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Tokens.rounding.full
                                color: Colours.tPalette.m3onSurface
                                opacity: !parent.selected && parent.hovered ? 0.08 : 0

                                Behavior on opacity {
                                    Anim {
                                        type: Anim.DefaultEffects
                                    }
                                }
                            }

                            StyledText {
                                id: chipLabel

                                anchors.centerIn: parent
                                text: modelData.t + " · " + root.kindCount(modelData.k)
                                font: Tokens.font.label.medium
                                color: parent.selected ? Colours.tPalette.m3onPrimaryContainer : Colours.tPalette.m3onSurfaceVariant
                            }

                            MouseArea {
                                id: chipMouse

                                anchors.fill: parent
                                hoverEnabled: root.hoverLive
                                onClicked: root.filterKind = modelData.k
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: "Pinned (" + root.pinItems().length + ")"
            color: Colours.tPalette.m3onSurfaceVariant
            font: Tokens.font.label.large
            visible: root.filterKind === "all" || root.filterKind === "pinned"
        }

        StyledListView {
            id: pinList

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(180, count * 87)
            visible: count > 0 && (root.filterKind === "all" || root.filterKind === "pinned")
            clip: true
            spacing: Tokens.spacing.small
            model: root.pinItems()

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: pinList
            }

            delegate: ClipRow {
                required property var modelData

                width: pinList.width
                entry: modelData.entry
                pinned: true
                hoverKey: root.hoverKey
                rowKey: modelData.key
                hoverLive: root.hoverLive
                uiActive: root.previewTarget === null
                menuOpen: false
                onHoverPart: part => root.reportHover(modelData.key, part)
                onClicked: root.activateEntry(modelData)
                onDoubleClicked: root.activateEntry(modelData)
                onPreviewClicked: root.openPreview(modelData)
                onPinClicked: root.togglePin(modelData)
                onDelClicked: root.deleteEntry(modelData)
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: "No pinned items yet — hover a card and pin it with ☆"
            color: Colours.tPalette.m3onSurfaceVariant
            font: Tokens.font.body.small
            visible: root.pinItems().length === 0 && (root.filterKind === "all" || root.filterKind === "pinned")
        }

        StyledText {
            Layout.fillWidth: true
            text: "History (" + root.histItems().length + ")"
            color: Colours.tPalette.m3onSurfaceVariant
            font: Tokens.font.label.large
            visible: root.filterKind !== "pinned"
        }

        StyledListView {
            id: histList

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.filterKind !== "pinned"
            clip: true
            spacing: Tokens.spacing.small
            model: root.histItems()

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: histList
            }

            delegate: ClipRow {
                required property var modelData

                width: histList.width
                entry: modelData.entry
                pinned: false
                hoverKey: root.hoverKey
                rowKey: modelData.key
                hoverLive: root.hoverLive
                uiActive: root.previewTarget === null
                menuOpen: false
                onHoverPart: part => root.reportHover(modelData.key, part)
                onClicked: root.activateEntry(modelData)
                onDoubleClicked: root.activateEntry(modelData)
                onPreviewClicked: root.openPreview(modelData)
                onPinClicked: root.togglePin(modelData)
                onDelClicked: root.deleteEntry(modelData)
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            TextButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Clear history"
                onClicked: service.wipeHistory()
            }
        }
    }

    // Preview overlay (flyout): full content + actions
    Item {
        anchors.fill: parent
        visible: root.previewTarget !== null

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLow

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40

                    IconButton {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "chevron_left"
                        onClicked: root.previewBack()
                    }

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: 48
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Preview"
                        font: Tokens.font.title.small
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.previewLoading ? "Loading…" : root.previewMeta
                    color: Colours.tPalette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Flickable {
                        anchors.fill: parent
                        visible: !root.previewIsImage() && !root.previewLoading
                        clip: true
                        contentWidth: width
                        contentHeight: previewBody.height
                        boundsBehavior: Flickable.StopAtBounds

                        StyledText {
                            id: previewBody

                            width: parent.width
                            text: root.previewText
                            font: Tokens.font.body.medium
                            wrapMode: Text.Wrap
                        }
                    }

                    Image {
                        anchors.fill: parent
                        visible: root.previewIsImage() && root.previewImage !== "" && !root.previewLoading
                        source: visible ? "file://" + root.previewImage : ""
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    TextButton {
                        text: "Copy"
                        type: TextButton.Filled
                        onClicked: root.previewCopy()
                    }

                    TextButton {
                        text: root.previewIsPin() ? "Unpin" : "Pin"
                        onClicked: root.previewPinToggle()
                    }

                    TextButton {
                        text: "Delete"
                        onClicked: root.previewDelete()
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "clipboardUi"

        function setFilter(kind: string): void {
            if (["all", "text", "images", "links", "code", "pinned"].includes(kind)) {
                root.query = "";
                root.filterKind = kind;
            }
        }

        function previewTop(): void {
            const h = root.histMatches();
            if (h.length > 0)
                root.openPreviewHistory(h[0]);
        }
    }
}
