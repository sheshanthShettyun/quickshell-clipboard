pragma ComponentBehavior: Bound

import QtQuick

// One clipboard row: thumbnail/badge + preview text + pin/delete buttons.
Item {
    id: row

    property var entry
    // true when this row renders a pinned entry (button becomes unpin)
    property bool pinned: false
    // UI font, matches the Caelestia shell bars/panels
    property string uiFont: "Rubik"

    signal clicked()
    signal pinClicked()
    signal delClicked()

    implicitHeight: 64

    Rectangle {
        id: bg

        anchors.fill: parent
        anchors.margins: 2
        radius: 10
        color: hover.containsMouse ? "#313244" : "#242438"
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        onClicked: row.clicked()

        Row {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 10

            // Thumbnail for images, type badge otherwise
            Item {
                width: 48
                height: 48
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    visible: row.entry && row.entry.isImage && row.entry.thumb !== ""
                    source: visible ? "file://" + row.entry.thumb : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: "#45475a"
                    visible: !(row.entry && row.entry.isImage && row.entry.thumb !== "")

                    Text {
                        anchors.centerIn: parent
                        text: row.entry && row.entry.isImage ? "IMG" : "TXT"
                        color: "#bac2de"
                        font.family: row.uiFont
                        renderType: Text.NativeRendering
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
            }

            Text {
                width: parent.width - 48 - 76 - 20
                anchors.verticalCenter: parent.verticalCenter
                text: row.entry ? row.entry.preview : ""
                color: "#cdd6f4"
                font.family: row.uiFont
                renderType: Text.NativeRendering
                font.pixelSize: 13
                elide: Text.ElideRight
                maximumLineCount: 3
                wrapMode: Text.Wrap
            }

            // Pin / unpin
            Rectangle {
                width: 30
                height: 30
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                color: pinHover.containsMouse ? "#45475a" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: row.pinned ? "★" : "☆"
                    color: row.pinned ? "#f9e2af" : "#bac2de"
                    font.family: row.uiFont
                    renderType: Text.NativeRendering
                    font.pixelSize: 16
                }

                MouseArea {
                    id: pinHover

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: row.pinClicked()
                }
            }

            // Delete
            Rectangle {
                width: 30
                height: 30
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                color: delHover.containsMouse ? "#45475a" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: "#bac2de"
                    font.family: row.uiFont
                    renderType: Text.NativeRendering
                    font.pixelSize: 14
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
