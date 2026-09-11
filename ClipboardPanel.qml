pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Right-side clipboard panel window (one instance per screen, shown on active).
PanelWindow {
    id: win

    required property ShellScreen modelData
    property bool isActiveScreen: false
    property bool panelOpen: false
    property var service
    property var pins

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
    // UI font, matches the Caelestia shell bars/panels — change here to restyle
    property string uiFont: "Rubik"

    onVisibleChanged: {
        if (visible) {
            win.query = "";
            searchInput.forceActiveFocus();
        }
    }

    Shortcut {
        sequences: ["Escape"]
        onActivated: win.requestClose()
    }

    function matchQuery(text: string): bool {
        if (win.query === "")
            return true;
        return text.toLowerCase().includes(win.query.toLowerCase());
    }

    function histMatches(): var {
        if (!win.service)
            return [];
        return win.service.entries.filter(e => win.matchQuery(e.preview));
    }

    function pinMatches(): var {
        if (!win.pins)
            return [];
        return win.pins.pins.filter(p => win.matchQuery(p.label || ""));
    }

    function copyFirst(): void {
        const p = win.pinMatches();
        if (p.length > 0) {
            win.pins.copyPin(p[0]);
            win.requestClose();
            return;
        }
        const h = win.histMatches();
        if (h.length > 0) {
            win.service.copyEntry(h[0]);
            win.requestClose();
        }
    }

    function pinEntry(e: var): void {
        if (!e || !win.pins)
            return;
        if (e.isImage) {
            const dest = win.pins.dir + "/pin-" + Date.now() + "-" + e.cid + ".bin";
            win.service.exportImage(e, dest, (arg, res) => {
                if (res === "OK")
                    win.pins.addImage(arg.mime, arg.preview, dest);
            });
        } else {
            win.service.decodeText(e, (arg, text) => {
                win.pins.addText(arg.preview, text);
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

    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e"
        radius: 16
        border.color: "#313244"
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Header
            Row {
                width: parent.width
                height: 28

                Text {
                    text: "Clipboard"
                    color: "#cdd6f4"
                    font.family: win.uiFont
                    renderType: Text.NativeRendering
                    font.pixelSize: 17
                    font.bold: true
                    width: parent.width - 120
                    verticalAlignment: Text.AlignVCenter
                    height: parent.height
                }

                Text {
                    text: win.service && win.service.loading ? "Loading…" : "Reload"
                    color: "#89b4fa"
                    font.family: win.uiFont
                    renderType: Text.NativeRendering
                    font.pixelSize: 13
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        enabled: !(win.service && win.service.loading)
                        onClicked: win.service.refresh()
                    }
                }

                Text {
                    text: "  ✕"
                    color: "#bac2de"
                    font.family: win.uiFont
                    renderType: Text.NativeRendering
                    font.pixelSize: 15
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        onClicked: win.requestClose()
                    }
                }
            }

            // Search
            Rectangle {
                width: parent.width
                height: 38
                radius: 10
                color: "#11111b"

                TextInput {
                    id: searchInput

                    anchors.fill: parent
                    anchors.margins: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: "#cdd6f4"
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
                    anchors.margins: 10
                    verticalAlignment: Text.AlignVCenter
                    text: "Search clipboard…"
                    color: "#585b70"
                    font.family: win.uiFont
                    renderType: Text.NativeRendering
                    font.pixelSize: 14
                    visible: searchInput.displayText === ""
                }
            }

            // Pinned section
            Text {
                text: "Pinned (" + win.pinMatches().length + ")"
                color: "#f9e2af"
                font.family: win.uiFont
                renderType: Text.NativeRendering
                font.pixelSize: 13
                font.bold: true
            }

            ListView {
                id: pinList

                width: parent.width
                height: Math.min(200, count * 68)
                visible: count > 0
                clip: true
                spacing: 2
                model: win.pinMatches()

                delegate: ClipRow {
                    required property var modelData

                    width: pinList.width
                    uiFont: win.uiFont
                    entry: modelData.kind === "image" ? {
                        preview: modelData.label,
                        isImage: true,
                        thumb: modelData.path
                    } : {
                        preview: modelData.label,
                        isImage: false,
                        thumb: ""
                    }
                    pinned: true
                    onClicked: {
                        win.pins.copyPin(modelData);
                        win.requestClose();
                    }
                    onPinClicked: win.unpin(modelData)
                    onDelClicked: win.unpin(modelData)
                }
            }

            Text {
                text: "No pinned items — hover a row and hit ☆"
                color: "#585b70"
                font.family: win.uiFont
                renderType: Text.NativeRendering
                font.pixelSize: 12
                visible: win.pinMatches().length === 0
            }

            // History section
            Text {
                text: "History (" + win.histMatches().length + ")"
                color: "#89b4fa"
                font.family: win.uiFont
                renderType: Text.NativeRendering
                font.pixelSize: 13
                font.bold: true
            }

            ListView {
                id: histList

                width: parent.width
                height: parent.height - y
                clip: true
                spacing: 2
                model: win.histMatches()

                delegate: ClipRow {
                    required property var modelData

                    width: histList.width
                    uiFont: win.uiFont
                    entry: modelData
                    pinned: false
                    onClicked: {
                        win.service.copyEntry(modelData);
                        win.requestClose();
                    }
                    onPinClicked: win.pinEntry(modelData)
                    onDelClicked: win.service.deleteEntry(modelData)
                }
            }
        }
    }
}
