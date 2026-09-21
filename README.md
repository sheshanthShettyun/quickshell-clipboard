# quickshell-clipboard

A clipboard drawer for the [Caelestia](https://github.com/caelestia-dots/shell)
Quickshell shell, backed by [cliphist](https://github.com/sentriz/cliphist).
Edge-Drop-inspired UX (filter chips, preview flyout) built entirely from
native Caelestia primitives — `Colours`, `Tokens`, `StyledText`,
`MaterialIcon`, `StateLayer`, `SearchBar`, `IconButton`, `TextButton`.

> Previously this repo held a standalone `qs -c clipboard` panel. That is
> retired; the clipboard now lives as `modules/clipboard/` inside the shell.

## Features

- **Image thumbnails** — decoded lazily to a thumbnail cache
- **Wipe-proof pins** — `~/.local/share/clipboard-panel/pins.json`, survive
  `cliphist wipe`
- **Search** — `Enter` copies the top match
- **Category chips** — All / Text / Images / Links / Code / Pinned with live
  counts and a sliding spring pill, combined with search
- **Preview flyout** — full scrollable text or full-size image plus
  Copy / Pin / Delete; `Esc` steps back out
- **Content-type icons** — Material Symbols per kind (text / link / code /
  image thumbnail)
- **Overflow menu** per card (Preview / Pin / Delete), press-and-hold opens it
- **Clear history** pill (pins survive it)
- **OSD coexistence** — the brightness/volume controller docks beside the
  open drawer instead of hiding under it

## Files

| File | Role |
| ---- | ---- |
| `modules/clipboard/Wrapper.qml` | drawer chrome (slide + fade, `offsetScale` contract) |
| `modules/clipboard/Content.qml` | search, chips, pinned + history, preview overlay |
| `modules/clipboard/ClipRow.qml` | one card: icon/thumbnail + text + actions + menu |
| `modules/clipboard/ClipService.qml` | cliphist backend + content-kind detection |
| `modules/clipboard/Pins.qml` | pinned entries JSON store |

Plus small wiring edits in the shell (see Install): `ScreenState.qml`,
`drawers/Panels.qml`, `drawers/ContentWindow.qml`, `drawers/Regions.qml`,
`Shortcuts.qml`, and one Hyprland bind.

## Dependencies

- Caelestia shell (Quickshell based)
- `cliphist`, `wl-clipboard` (`wl-copy`)
- Hyprland (keybind)

## Install

### 1. Collect clipboard history

```sh
wl-paste --type text --watch cliphist store
wl-paste --type image --watch cliphist store
```

### 2. Copy the module in

```bash
cp -r modules/clipboard ~/.config/quickshell/caelestia/modules/
```

### 3. Wire it into the shell

**`components/ScreenState.qml`** — add the drawer flag:

```qml
property bool clipboard
```

**`modules/drawers/Panels.qml`** — import, instantiate (right side,
vertically centered like the OSD), alias:

```qml
import qs.modules.clipboard as Clipboard
```

```qml
Clipboard.Wrapper {
    id: clipboard
    screenState: root.screenState
    anchors.verticalCenter: parent.verticalCenter
    anchors.right: parent.right
}
```

```qml
readonly property alias clipboard: clipboard
```

**`modules/drawers/ContentWindow.qml`** — backdrop blob next to `sidebarBg`:

```qml
PanelBg {
    id: clipboardBg
    panel: panels.clipboard
    deformAmount: 0.03
    implicitHeight: panel.height * (1 / rawDeformMatrix.m22) + 2
}
```

**`modules/drawers/Regions.qml`** — input region next to `sidebarRegion`:

```qml
R {
    panel: root.panels.clipboard
    x: root.win.width - width
    width: panel.width * (1 - root.panels.clipboard.offsetScale) + root.borderThickness
}
```

**`modules/Shortcuts.qml`** — registers the `caelestia:clipboard` global:

```qml
CustomShortcut {
    name: "clipboard"
    description: "Toggle clipboard"
    onPressed: {
        const screenState = ShellState.forActive();
        screenState.clipboard = !screenState.clipboard;
    }
}
```

### 4. Bind a key + reload

```ini
bind = SUPER, V, global, caelestia:clipboard
```

```bash
hyprctl reload
# restart the shell, then:
qs -c caelestia ipc call drawers toggle clipboard
```

### 5. OSD side-by-side (optional)

For the volume/brightness controller to dock beside the open drawer,
in `modules/osd/Wrapper.qml` add:

```qml
required property real clipboardWidth
property real shift: screenState.clipboard ? clipboardWidth + 6 : 0
Behavior on shift { Anim {} }
anchors.rightMargin: (-implicitWidth - 5 - sidebarOffset) * offsetScale + shift
```

pass `clipboardWidth: clipboard.implicitWidth` at its `Panels.qml`
instantiation, and extend the hover zone in `modules/drawers/Interactions.qml`:

```js
const showOsd = inRightPanel(panels.osdWrapper, x, y);
```

(stays edge-only; the shift handles the rest).

## Notes

- Binary clipboard data never passes through QML — all decode/copy/delete
  happens in `sh` pipelines; QML only sees text previews and file paths.
- Thumbnails live under `~/.cache/clipboard-panel/thumbs/<run-id>/`.
- Back up `modules/clipboard/` before running `caelestia update`, which can
  overwrite the shell config directory.
