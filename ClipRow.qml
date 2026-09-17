pragma ComponentBehavior: Bound

import QtQuick

// One clipboard card: icon/thumbnail + text + actions.
// Mirrors the Caelestia notification-card language:
// layered surface, soft radius, generous padding, subtle icon actions.
Item {
    id: row

    property var entry
    property bool pinned: false
    // Panel-driven highlight (see hoverKey) — never sticks like containsMouse.
    property bool highlighted: false
    property string uiFont: "Rubik"
    property string iconFont: "Material Symbols Rounded"
    property var theme

    signal clicked()
    signal doubleClicked()
    signal pinClicked()
    signal delClicked()
    signal hovered(bool on)

    readonly property bool isImage: row.entry && row.entry.isImage
    readonly property string kind: row.entry && row.entry.kind ? row.entry.kind : "text"
    readonly property string glyph: row.kind === "url" ? "link" : row.kind === "code" ? "code" : "description"
    readonly property real iconBox: row.isImage ? 96 : 44

    implicitHeight: 88

    Timer {
        id: clickTimer

        interval: 260
        onTriggered: row.clicked()
    }

    Rectangle {
        id: bg

        anchors.fill: parent
        anchors.margins: 2
        radius: 16
        color: row.highlighted ? row.theme.surfaceContainerHighest : row.theme.surfaceContainerHigh

        Behavior on color {
            NumberAnimation {
                duration: 150
            }
        }
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        onClicked: clickTimer.restart()
        onDoubleClicked: {
            clickTimer.stop();
            row.doubleClicked();
        }
        onContainsMouseChanged: row.hovered(containsMouse)

        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // Icon / thumbnail
            Item {
                width: row.iconBox
                height: 64
                anchors.verticalCenter: parent.verticalCenter

                // Thumbnail: aspect-preserving, never cropped
                Image {
                    anchors.fill: parent
                    visible: row.isImage && row.entry.thumb !== ""
                    source: visible ? "file://" + row.entry.thumb : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                // Type badge for non-image entries
                Rectangle {
                    width: 44
                    height: 44
                    anchors.centerIn: parent
                    radius: 22
                    color: row.theme.surfaceContainerHighest
                    visible: !row.isImage

                    Text {
                        anchors.centerIn: parent
                        text: row.glyph
                        font.family: row.iconFont
                        font.pixelSize: 20
                        renderType: Text.NativeRendering
                        color: row.theme.inkDim
                    }
                }
            }

            // Text column
            Item {
                width: parent.width - row.iconBox - 68 - 48
                height: 64
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
                        font.pixelSize: 12
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
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }

            // Actions
            Item {
                width: 68
                height: 40
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: pinHover.containsMouse ? row.theme.surfaceContainerHighest : "transparent"

                        Behavior on color {
                            NumberAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "star"
                            font.family: row.iconFont
                            font.pixelSize: 19
                            renderType: Text.NativeRendering
                            color: row.pinned ? row.theme.tertiary : row.theme.inkDim
                            opacity: (row.pinned || pinHover.containsMouse) ? 1 : 0.7

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }

                        MouseArea {
                            id: pinHover

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: row.pinClicked()
                        }
                    }

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: delHover.containsMouse ? row.theme.surfaceContainerHighest : "transparent"

                        Behavior on color {
                            NumberAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            font.family: row.iconFont
                            font.pixelSize: 19
                            renderType: Text.NativeRendering
                            color: row.theme.inkDim
                            opacity: delHover.containsMouse ? 1 : 0.7

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }

                        MouseArea {
                            id: delHover

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: row.delClicked()
                        }
                    }
                }
            }
        }
    }
}
