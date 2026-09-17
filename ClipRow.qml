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
    // UI font: Caelestia primary (loaded via FontLoader in shell.qml)
    property string uiFont: "Google Sans Flex"
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
    readonly property real iconBox: row.isImage ? 120 : 56

    // Press point (row coords) for the ripple
    property real pressX: 0
    property real pressY: 0

    implicitHeight: 116

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
        onPressed: e => {
            row.pressX = e.x - 2;
            row.pressY = e.y - 2;
            ripple.scale = 1;
            ripple.opacity = 0.12;
            rippleAnim.restart();
        }

        Row {
            anchors.fill: parent
            anchors.margins: 12
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
                width: parent.width - row.iconBox - 80 - 48
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

            // Actions
            Item {
                width: 80
                height: 48
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: pinHover.containsMouse ? row.theme.surfaceContainerHighest : "transparent"

                        Behavior on color {
                            NumberAnimation {
                                duration: 200
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "star"
                            font.family: row.iconFont
                            font.pixelSize: 22
                            renderType: Text.NativeRendering
                            color: row.pinned ? row.theme.tertiary : row.theme.inkDim
                            opacity: (row.pinned || pinHover.containsMouse) ? 1 : 0.7

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
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
                        width: 36
                        height: 36
                        radius: 18
                        color: delHover.containsMouse ? row.theme.surfaceContainerHighest : "transparent"

                        Behavior on color {
                            NumberAnimation {
                                duration: 200
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            font.family: row.iconFont
                            font.pixelSize: 22
                            renderType: Text.NativeRendering
                            color: row.theme.inkDim
                            opacity: delHover.containsMouse ? 1 : 0.7

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
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
