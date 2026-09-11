pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Backend for the standalone clipboard panel.
// All binary clipboard data stays in shell pipelines; QML only sees text.
Item {
    id: root
    visible: false

    property list<var> entries: []
    property bool loading: false
    property int runId: 0

    readonly property string cacheBase: Quickshell.env("HOME") + "/.cache/clipboard-panel/thumbs"
    readonly property int maxEntries: 100
    readonly property int maxImages: 30

    property var _seqCb: null
    property var _textCb: null
    property var _textArg: null
    property var _pinCb: null
    property var _pinArg: null

    Process {
        id: listProc

        stdout: StdioCollector {
            onStreamFinished: root._onList(text)
        }
    }

    Process {
        id: thumbProc

        stdout: StdioCollector {
            onStreamFinished: root._onThumbs(text)
        }
    }

    Process {
        id: seqProc

        stdout: StdioCollector {
            onStreamFinished: {
                const cb = root._seqCb;
                root._seqCb = null;
                root.loading = false;
                if (cb)
                    cb(text);
            }
        }
    }

    Process {
        id: textProc

        stdout: StdioCollector {
            onStreamFinished: {
                const cb = root._textCb;
                const arg = root._textArg;
                root._textCb = null;
                root._textArg = null;
                if (cb)
                    cb(arg, text);
            }
        }
    }

    Process {
        id: pinProc

        stdout: StdioCollector {
            onStreamFinished: {
                const cb = root._pinCb;
                const arg = root._pinArg;
                root._pinCb = null;
                root._pinArg = null;
                if (cb)
                    cb(arg, text.trim());
            }
        }
    }

    function refresh(): void {
        root.loading = true;
        root.runId = Date.now();
        listProc.running = false;
        listProc.command = ["sh", "-c", "cliphist list | head -n " + root.maxEntries];
        listProc.running = true;
    }

    function _onList(output: string): void {
        const parsed = [];
        for (const line of output.split("\n")) {
            const m = line.match(/^(\d+)\t(.*)$/);
            if (!m)
                continue;
            const preview = m[2];
            const isImage = preview.startsWith("[[ binary data");
            let mime = "";
            if (isImage) {
                const mm = preview.match(/\[\[ binary data \S+ (png|jpe?g|gif|webp|bmp)/);
                let fmt = mm ? mm[1] : "png";
                if (fmt === "jpg")
                    fmt = "jpeg";
                mime = "image/" + fmt;
            }
            parsed.push({
                cid: parseInt(m[1], 10),
                preview: preview,
                isImage: isImage,
                mime: mime,
                thumb: ""
            });
            if (parsed.length >= root.maxEntries)
                break;
        }
        root.entries = parsed;
        root._genThumbs();
    }

    function _genThumbs(): void {
        const imgs = root.entries.filter(e => e.isImage).slice(0, root.maxImages);
        if (imgs.length === 0) {
            root.loading = false;
            return;
        }
        const dir = root.cacheBase + "/" + root.runId;
        let specs = "";
        for (const e of imgs)
            specs += e.cid + " " + (e.mime === "image/jpeg" ? "jpg" : "png") + "\n";
        const script = "DIR=\"" + dir + "\"; mkdir -p \"$DIR\"; while read -r id ext; do f=\"$DIR/$id.$ext\"; if cliphist decode \"$id\" > \"$f\" 2>/dev/null && [ -s \"$f\" ]; then echo \"$id $f\"; else rm -f \"$f\"; fi; done <<'SPECS'\n" + specs + "SPECS";
        thumbProc.running = false;
        thumbProc.command = ["sh", "-c", script];
        thumbProc.running = true;
    }

    function _onThumbs(output: string): void {
        const byId = {};
        for (const line of output.split("\n")) {
            const m = line.match(/^(\d+) (\S+)$/);
            if (m)
                byId[parseInt(m[1], 10)] = m[2];
        }
        root.entries = root.entries.map(e => {
            if (e.isImage && byId[e.cid])
                return {
                    cid: e.cid,
                    preview: e.preview,
                    isImage: true,
                    mime: e.mime,
                    thumb: byId[e.cid]
                };
            return e;
        });
        root.loading = false;
    }

    function _safeId(cid: var): int {
        const n = Math.floor(Number(cid));
        return isFinite(n) && n >= 0 ? n : -1;
    }

    function copyEntry(e: var): void {
        const id = root._safeId(e.cid);
        if (id < 0)
            return;
        if (e.isImage)
            Quickshell.execDetached(["sh", "-c", "cliphist decode " + id + " 2>/dev/null | wl-copy --type " + (e.mime === "image/jpeg" ? "image/jpeg" : "image/png")]);
        else
            Quickshell.execDetached(["sh", "-c", "cliphist decode " + id + " 2>/dev/null | wl-copy"]);
    }

    function deleteEntry(e: var): void {
        const id = root._safeId(e.cid);
        if (id < 0)
            return;
        root.loading = true;
        root._seqCb = () => root.refresh();
        seqProc.running = false;
        seqProc.command = ["sh", "-c", "cliphist list | awk -F'\t' '$1==" + id + "' | cliphist delete; echo DONE"];
        seqProc.running = true;
    }

    function decodeText(e: var, cb: var): void {
        const id = root._safeId(e.cid);
        if (id < 0)
            return;
        root._textCb = cb;
        root._textArg = e;
        textProc.running = false;
        textProc.command = ["sh", "-c", "cliphist decode " + id + " 2>/dev/null"];
        textProc.running = true;
    }

    function exportImage(e: var, destPath: string, cb: var): void {
        const id = root._safeId(e.cid);
        if (id < 0)
            return;
        root._pinCb = cb;
        root._pinArg = e;
        pinProc.running = false;
        pinProc.command = ["sh", "-c", "cliphist decode " + id + " > '" + destPath + "' 2>/dev/null && [ -s '" + destPath + "' ] && echo OK || echo FAIL"];
        pinProc.running = true;
    }
}
