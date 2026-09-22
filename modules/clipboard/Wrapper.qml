pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import qs.components

// Clipboard drawer: floating right-side panel (OSD-style, vertically
// centered, fixed height) with the sidebar motion contract
// (offsetScale 0..1 slide + fade, DefaultSpatial).
Item {
    id: root

    required property ScreenState screenState

    readonly property bool shouldBeActive: screenState.clipboard
    property real offsetScale: shouldBeActive ? 0 : 1

    readonly property real totalPadding: content.anchors.margins + CUtils.clamp(content.anchors.margins - Config.border.thickness, 0, content.anchors.margins)

    visible: offsetScale < 1
    anchors.rightMargin: (-implicitWidth - 5) * offsetScale
    implicitWidth: 480
    implicitHeight: content.implicitHeight + totalPadding
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.large
        anchors.margins: CUtils.clamp(anchors.leftMargin - Config.border.thickness, 0, anchors.leftMargin)

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            implicitWidth: root.implicitWidth - content.anchors.leftMargin - content.anchors.margins
            implicitHeight: 828
            screenState: root.screenState
        }
    }
}
