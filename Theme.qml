pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Live bridge to the Caelestia dynamic scheme — the same source the
// sidebar/bar use. Updates automatically when the scheme changes
// (wallpaper switch, light/dark toggle). Falls back to sane dark
// values if the scheme file is missing.
Item {
    id: root
    visible: false

    property string surface: "#100d11"
    property string surfaceContainerLow: "#161218"
    property string surfaceContainer: "#1c181f"
    property string surfaceContainerHigh: "#231e25"
    property string surfaceContainerHighest: "#29242c"
    property string ink: "#ede2ee"
    property string inkDim: "#b1a8b3"
    property string primary: "#d7bde8"
    property string primaryContainer: "#5f4a6e"
    property string primaryContainerText: "#f2dbff"
    property string tertiary: "#ffd4e4"
    property string outline: "#7b737d"
    property string outlineVariant: "#4c464f"

    readonly property string schemePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/caelestia/scheme.json"

    FileView {
        id: store

        path: root.schemePath
        watchChanges: true
        printErrors: false
        onLoaded: root._apply(text())
        onFileChanged: root._apply(text())
    }

    function _apply(t: string): void {
        let c = null;
        try {
            c = JSON.parse(t).colours;
        } catch (err) {
            return;
        }
        if (!c)
            return;
        const keys = ["surface", "surfaceContainerLow", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "ink", "inkDim", "primary", "primaryContainer", "primaryContainerText", "tertiary", "outline", "outlineVariant"];
        for (const k of keys) {
            const src = k === "ink" ? "onSurface" : k === "inkDim" ? "onSurfaceVariant" : k === "primaryContainerText" ? "onPrimaryContainer" : k;
            if (c[src])
                root[k] = "#" + c[src];
        }
    }
}
