import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Standalone clipboard panel (config name: "clipboard").
// Run persistently with: qs -c clipboard -d
// Toggle with: qs -c clipboard ipc call clipboard toggle
ShellRoot {
    id: root

    property bool open: false
    property ShellScreen activeScreen: null

    function toggle(): void {
        if (root.open) {
            root.open = false;
            return;
        }
        let scr = null;
        const mon = Hyprland.focusedMonitor;
        if (mon) {
            for (const s of Quickshell.screens) {
                if (s.name === mon.name) {
                    scr = s;
                    break;
                }
            }
        }
        root.activeScreen = scr ?? Quickshell.screens[0] ?? null;
        clipboardSvc.refresh();
        root.open = true;
    }

    function close(): void {
        root.open = false;
    }

    ClipboardService {
        id: clipboardSvc
    }

    PinsStore {
        id: pinsStore
    }

    Theme {
        id: sysTheme
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            if (!root.open)
                root.toggle();
        }

        function close(): void {
            root.close();
        }

        function refresh(): void {
            clipboardSvc.refresh();
        }
    }

    Variants {
        model: Quickshell.screens

        ClipboardPanel {
            screen: modelData
            isActiveScreen: root.activeScreen === modelData
            panelOpen: root.open
            service: clipboardSvc
            pins: pinsStore
            theme: sysTheme
            onRequestClose: root.close()
        }
    }
}
