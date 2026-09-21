pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// One clipboard card: icon/thumbnail + text + actions.
// Native Caelestia language: StyledRect base, StateLayer hover + ripple,
// MaterialIcon glyphs, StyledText type, panel-owned hoverKey discipline.
Item {
    id: row

    property var entry
    property bool pinned: false
    property string hoverKey: ""
    property string rowKey: ""
    property bool hoverLive: true
    property bool menuOpen: false
    property bool uiActive: true
    property double menuOpenedAt: 0
    property bool holdUsed: false

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

    implicitHeight: 81

    onRowActiveChanged: {
        if (!row.rowActive)
            row.menuOpen = false;
    }

    StyledRect {
        id: bg

        anchors.fill: parent
        anchors.margins: 2
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainerHigh

        // Icon / thumbnail + text (non-interactive; StateLayer below
        // handles all row gestures so tap delivery is unambiguous)
        Row {
            anchors.fill: parent
            anchors.margins: 12
            anchors.rightMargin: 104
            spacing: 12

            Item {
                width: row.iconBox
                height: 62
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    visible: row.isImage && row.entry.thumb !== ""
                    source: visible ? "file://" + row.entry.thumb : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Rectangle {
                    width: 40
                    height: 40
                    anchors.centerIn: parent
                    radius: 20
                    color: Colours.tPalette.m3surfaceContainerHighest
                    visible: !row.isImage

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: row.glyph
                        fontStyle: Tokens.font.icon.medium
                        color: Colours.tPalette.m3onSurfaceVariant
                    }
                }
            }

            Item {
                width: parent.width - row.iconBox - 24
                height: 62
                anchors.verticalCenter: parent.verticalCenter

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 2

                    StyledText {
                        width: parent.width
                        text: row.entry ? (row.entry.title || row.entry.preview || "") : ""
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                        maximumLineCount: row.isImage ? 1 : 2
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        width: parent.width
                        text: row.isImage && row.entry ? (row.entry.sub || "") : ""
                        visible: text !== ""
                        color: Colours.tPalette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Action cluster above the StateLayer so taps are unambiguous
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

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "star"
                        fontStyle: Tokens.font.icon.medium
                        fill: row.pinned ? 1 : 0
                        color: row.pinned ? Colours.tPalette.m3tertiary : Colours.tPalette.m3onSurfaceVariant
                        opacity: (row.pinned || row.starLit) ? 1 : 0.7

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: row.hoverLive
                        onContainsMouseChanged: row.hoverPart(containsMouse ? "star" : "row")
                        onClicked: row.pinClicked()
                    }
                }

                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: "transparent"

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "more_vert"
                        fontStyle: Tokens.font.icon.medium
                        color: Colours.tPalette.m3onSurfaceVariant
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
                        onContainsMouseChanged: row.hoverPart(containsMouse ? "menu" : "row")
                        onClicked: {
                            row.menuOpenedAt = Date.now();
                            row.menuOpen = !row.menuOpen;
                        }
                    }
                }
            }
        }

        // StateLayer: hover tint + press ripple + all row gestures.
        // Topmost so taps land here unless on the action buttons above... 
        // NOTE: placed below actions in paint order via explicit z so that
        // buttons stay clickable while the layer still covers the body.
        StateLayer {
            anchors.fill: parent
            z: -1
            disabled: !row.hoverLive
            onClicked: {
                if (row.holdUsed) {
                    row.holdUsed = false;
                    return;
                }
                if (row.menuOpen && Date.now() - row.menuOpenedAt < 500)
                    return;
                row.clicked();
            }
            onDoubleClicked: {
                row.holdUsed = false;
                if (row.menuOpen && Date.now() - row.menuOpenedAt < 500)
                    return;
                row.doubleClicked();
            }
            onContainsMouseChanged: row.hoverPart(containsMouse ? "row" : "")
            onPressAndHold: {
                row.holdUsed = true;
                row.menuOpen = true;
                row.menuOpenedAt = Date.now();
            }
            pressAndHoldInterval: 400
        }
    }

    // Overflow menu (Preview / Pin / Delete)
    Item {
        anchors.fill: parent
        visible: row.menuOpen && row.uiActive

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
            color: Colours.tPalette.m3surfaceContainerHighest

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
                        color: mHover.containsMouse ? Colours.tPalette.m3surfaceContainerHigh : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            spacing: 10

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.g
                                fontStyle: Tokens.font.icon.small
                                color: Colours.tPalette.m3onSurfaceVariant
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.t
                                font: Tokens.font.label.medium
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
