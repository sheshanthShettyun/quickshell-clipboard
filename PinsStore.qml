pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Pinned clipboard entries, stored as JSON so they survive `cliphist wipe`.
Item {
    id: root
    visible: false

    property list<var> pins: []

    readonly property string dir: Quickshell.env("HOME") + "/.local/share/clipboard-panel"
    readonly property string storePath: dir + "/pins.json"

    Component.onCompleted: Quickshell.execDetached(["sh", "-c", "mkdir -p '" + root.dir + "'"]);

    FileView {
        id: store

        path: root.storePath
        watchChanges: false
        printErrors: false
        onLoaded: {
            const t = text().trim();
            if (t !== "") {
                try {
                    root.pins = JSON.parse(t);
                } catch (err) {
                    console.warn("clipboard: pins.json parse failed:", err);
                }
            }
        }
    }

    function _save(): void {
        store.setText(JSON.stringify(root.pins));
    }

    function _b64(s: string): string {
        return Qt.btoa(unescape(encodeURIComponent(s)));
    }

    function addText(label: string, content: string): void {
        root.pins = [{
            kind: "text",
            label: label.slice(0, 80),
            b64: root._b64(content),
            created: Date.now()
        }].concat(root.pins);
        root._save();
    }

    function addImage(mime: string, label: string, path: string): void {
        root.pins = [{
            kind: "image",
            mime: mime,
            label: label,
            path: path,
            created: Date.now()
        }].concat(root.pins);
        root._save();
    }

    function removeAt(i: number): void {
        if (i < 0 || i >= root.pins.length)
            return;
        const p = root.pins[i];
        root.pins = root.pins.filter((_, j) => j !== i);
        if (p && p.kind === "image" && p.path)
            Quickshell.execDetached(["sh", "-c", "rm -f '" + p.path + "'"]);
        root._save();
    }

    function copyPin(p: var): void {
        if (!p)
            return;
        if (p.kind === "image" && p.path && p.mime) {
            const mime = p.mime === "image/jpeg" ? "image/jpeg" : "image/png";
            Quickshell.execDetached(["sh", "-c", "wl-copy --type " + mime + " < '" + p.path + "'"]);
        } else if (p.b64) {
            Quickshell.execDetached(["sh", "-c", "echo '" + p.b64 + "' | base64 -d | wl-copy"]);
        }
    }
}
