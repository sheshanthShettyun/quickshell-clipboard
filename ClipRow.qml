pragma ComponentBehavior: Bound

import QtQuick

// One clipboard card: icon/thumbnail + text + actions.
// Mirrors the Caelestia notification-card language:
// layered surface, soft radius, generous padding, subtle icon actions.
//
// Hover discipline (nothing sticks): all hover VISUALS derive from the
// panel-owned hoverKey ("<rowKey>" or "<rowKey>:<part>"); local
// containsMouse only emits transitions via hoverPart(). All hover
// tracking disables with hoverLive (toggled on panel close/open),
// which resets any frozen Qt hover state.
Item {
    id: row

    property var entry
    property bool pinned: false
    property string uiFont: "Google Sans Flex"
    property string iconFont: "Material Symbols Rounded"
    property var theme

    // Panel-driven state
    property string hoverKey: ""
    property string rowKey: ""
    property bool hoverLive: true
    property bool menuOpen: false
    property double menuOpenedAt: 0
    property bool uiActive: true

    readonly property bool highlighted: row.hoverKey === row.rowKey || row.hoverKey.indexOf(row.rowKey + ":") === 0
    readonly property bool starLit: row.hoverKey === row.rowKey + ":star"
    readonly property bool menuLit: row.hoverKey === row.rowKey + ":menu" || row.menuOpen
    readonly property bool rowActive: row.highlighted

    signal clicked()
    signal doubleClicked()
    signal pinClicked()
    signal delClicked()
    signal previewClicked()
    signal hoverPart(string part)

    readonly property bool isImage: row.entry && row.entry.isImage
    readonly property string kind: row.entry && row.entry.kind ? row.entry.kind : "text"
    readonly property string glyph: row.kind === "url" ? "link" : row.kind === "code" ? "code" : "description"
    readonly property real iconBox: row.isImage ? 120 : 56

    // Press point (row coords) for the ripple
    property real pressX: 0
    property real pressY: 0
    // Press-and-hold opens the menu (big gesture target — no precision
    // needed). The release-click afterwards is swallowed via holdUsed.
    property bool holdUsed: false

    implicitHeight: 116

    onRowActiveChanged: {
        if (!row.rowActive)
            row.menuOpen = false;
    }

    Timer {
        id: clickTimer

        interval: 260
        onTriggered: {
            row.holdUsed = false;
            // A tap that just opened the menu must never also activate
            // the row (double delivery / bounce taps).
            if (row.menuOpen && Date.now() - row.menuOpenedAt < 500)
                return;
            row.clicked();
        }
    }

    Rectangle {
        id: bg

        anchors.fill: parent
        anchors.margins: 2
        radius: 16
        color: row.theme.surfaceContainerHigh
        clip: true

        // StateLayer hover: m3onSurface @ 0.08, 200ms DefaultEffects
        // [0.34,0.8,0.34,1] — base color stays constant like the shell.
        Rectangle {
            anchors.fill: parent
            radius: 16
            color: row.theme.ink
            opacity: row.highlighted ? 0.08 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.Bezier
                    easing.bezierCurve: [0.34, 0.8, 0.34, 1.0]
                }
            }
        }

        // Press ripple (simplified StateLayer): expanding circle clipped
        // to the card, 600ms standard easing, then fade.
        Rectangle {
            id: ripple

            width: 16
            height: 16
            radius: 8
            x: row.pressX - 8
            y: row.pressY - 8
            color: row.theme.ink
            opacity: 0
        }

        ParallelAnimation {
            id: rippleAnim

            alwaysRunToEnd: true

            NumberAnimation {
                target: ripple
                property: "scale"
                to: 48
                duration: 600
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.2, 0, 0, 1.0]
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 450
                }
                NumberAnimation {
                    target: ripple
                    property: "opacity"
                    to: 0
                    duration: 150
                }
            }
        }
    }

    // Row body: content only, NO nested interactive areas (nested hover
    // areas make tap delivery ambiguous).
    MouseArea {
        id: bodyArea

        anchors.fill: parent
        hoverEnabled: row.hoverLive
        pressAndHoldInterval: 400
        onClicked: clickTimer.restart()
        onDoubleClicked: {
            clickTimer.stop();
            row.holdUsed = false;
            if (row.menuOpen && Date.now() - row.menuOpenedAt < 500)
                return;
            row.doubleClicked();
        }
        onContainsMouseChanged: {
            if (!containsMouse && row.menuOpen)
                return;
            row.hoverPart(containsMouse ? "row" : "");
        }
        onPressed: e => {
            row.holdUsed = false;
            row.pressX = e.x - 2;
            row.pressY = e.y - 2;
            ripple.scale = 1;
            ripple.opacity = 0.12;
            rippleAnim.restart();
        }
        onPressAndHold: {
            row.holdUsed = true;
            row.menuOpen = true;
            row.menuOpenedAt = Date.now();
        }

        Row {
            anchors.fill: parent
            anchors.margins: 12
            // Leave room for the action cluster overlaying on the right
            anchors.rightMargin: 92
            spacing: 12

            // Icon / thumbnail
            Item {
                width: row.iconBox
                height: 88
                anchors.verticalCenter: parent.verticalCenter

                // Thumbnail: aspect-preserving, never cropped
                Image {
                    anchors.fill: parent
                    visible: row.isImage && row.entry.thumb !== ""
                    source: visible ? "file://" + row.entry.thumb : ""
                    asynchronous: true
                    sourceSize.width: row.iconBox * 2
                    sourceSize.height: 176
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                // Type badge for non-image entries
                Rectangle {
                    width: 56
                    height: 56
                    anchors.centerIn: parent
                    radius: 28
                    color: row.theme.surfaceContainerHighest
                    visible: !row.isImage

                    Text {
                        anchors.centerIn: parent
                        text: row.glyph
                        font.family: row.iconFont
                        font.pixelSize: 24
                        renderType: Text.NativeRendering
                        color: row.theme.inkDim
                    }
                }
            }

            // Text column
            Item {
                width: parent.width - row.iconBox - 96 - 48
                height: 88
                anchors.verticalCenter: parent.verticalCenter

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 2

                    Text {
                        width: parent.width
                        text: row.entry ? (row.entry.title || row.entry.preview || "") : ""
                        color: row.theme.ink
                        font.family: row.uiFont
                        renderType: Text.NativeRendering
                        font.pixelSize: 16
                        elide: Text.ElideRight
                        maximumLineCount: row.isImage ? 1 : 3
                        wrapMode: Text.Wrap
                    }

                    Text {
                        width: parent.width
                        text: row.isImage && row.entry ? (row.entry.sub || "") : ""
                        visible: text !== ""
                        color: row.theme.inkDim
                        font.family: row.uiFont
                        renderType: Text.NativeRendering
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // Action cluster: sibling overlay above the body area so taps are
    // unambiguous (topmost receiver wins, no nesting).
    Item {
        anchors.fill: parent

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                width: 44
                height: 44
                radius: 22
                color: "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "star"
                    font.family: row.iconFont
                    font.pixelSize: 22
                    renderType: Text.NativeRendering
                    color: row.pinned ? row.theme.tertiary : row.theme.inkDim
                    opacity: (row.pinned || row.starLit) ? 1 : 0.7

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: row.hoverLive
                    onContainsMouseChanged: {
                        if (!containsMouse && row.menuOpen)
                            return;
                        row.hoverPart(containsMouse ? "star" : "row");
                    }
                    onClicked: row.pinClicked()
                }
            }

            Rectangle {
                width: 44
                height: 44
                radius: 22
                color: "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "more_vert"
                    font.family: row.iconFont
                    font.pixelSize: 24
                    renderType: Text.NativeRendering
                    color: row.theme.inkDim
                    opacity: (row.menuOpen || row.menuLit) ? 1 : 0.7

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: row.hoverLive
                    onContainsMouseChanged: {
                        if (!containsMouse && row.menuOpen)
                            return;
                        row.hoverPart(containsMouse ? "menu" : "row");
                    }
                    onClicked: {
                        row.menuOpenedAt = Date.now();
                        row.hoverPart("menu");
                        row.menuOpen = !row.menuOpen;
                    }
                }
            }
        }
    }

    // Overflow menu (Preview / Pin / Delete), closes on action,
    // row-leave (via rowActive), or whenever the panel isn't in list mode.
    Item {
        anchors.fill: parent
        visible: row.menuOpen && row.uiActive

        // Click-away layer: any click outside the menu dismisses it
        // (ignores taps within 350ms of opening: double-taps and bounce
        // taps would toggle-then-dismiss otherwise).
        MouseArea {
            anchors.fill: parent
            onClicked: mouse => {
                mouse.accepted = true;
                if (Date.now() - row.menuOpenedAt < 350)
                    return;
                row.menuOpen = false;
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 84
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            height: menuCol.height + 16
            radius: 12
            color: row.theme.surfaceContainerHighest

            Column {
                id: menuCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 2

                Repeater {
                    model: [{
                        a: "preview",
                        g: "visibility",
                        t: "Preview"
                    }, {
                        a: "pin",
                        g: "star",
                        t: row.pinned ? "Unpin" : "Pin"
                    }, {
                        a: "del",
                        g: "delete",
                        t: "Delete"
                    }]

                    delegate: Rectangle {
                        required property var modelData

                        width: menuCol.width
                        height: 36
                        radius: 8
                        color: mHover.containsMouse ? row.theme.surfaceContainerHigh : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            spacing: 10

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.g
                                font.family: row.iconFont
                                font.pixelSize: 19
                                renderType: Text.NativeRendering
                                color: row.theme.inkDim
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.t
                                font.family: row.uiFont
                                font.pixelSize: 14
                                renderType: Text.NativeRendering
                                color: row.theme.ink
                            }
                        }

                        MouseArea {
                            id: mHover

                            anchors.fill: parent
                            hoverEnabled: row.hoverLive
                            onContainsMouseChanged: {
                                if (containsMouse)
                                    row.hoverPart("menu");
                            }
                            onClicked: {
                                const a = modelData.a;
                                row.menuOpen = false;
                                if (a === "preview")
                                    row.previewClicked();
                                else if (a === "pin")
                                    row.pinClicked();
                                else
                                    row.delClicked();
                            }
                        }
                    }
                }
            }
        }
    }
}
