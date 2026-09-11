# quickshell-clipboard

A standalone [Quickshell](https://quickshell.org/) clipboard panel backed by
[cliphist](https://github.com/sentriz/cliphist). Built for Hyprland alongside
the Caelestia shell, but it runs as its own independent config so shell
updates can't break it.

## Features

- **Image thumbnails** — image entries decoded lazily to a thumbnail cache
- **Wipe-proof pins** — pinned entries stored in
  `~/.local/share/clipboard-panel/pins.json`, survive `cliphist wipe`
- **Search** — type to filter history + pins (`Enter` copies the top match)
- **Per-row delete** — no separate delete mode needed
- **Opens on the focused monitor**, styled like the Caelestia shell
  (Rubik + `Text.NativeRendering`)

## Files

| File                 | Role                                              |
| -------------------- | ------------------------------------------------- |
| `shell.qml`          | `ShellRoot`, per-screen panel windows, IPC target |
| `ClipboardService.qml` | cliphist backend (list / decode / delete / copy) |
| `PinsStore.qml`      | pinned entries JSON store                         |
| `ClipboardPanel.qml` | panel window: search, pinned + history sections   |
| `ClipRow.qml`        | one row: thumbnail/badge + preview + pin/delete   |

## Dependencies

- `quickshell`
- `cliphist`
- `wl-clipboard` (`wl-copy`)
- Hyprland (window + keybind integration)

## Install

```bash
# 1. Put this repo at ~/.config/quickshell/clipboard
git clone https://github.com/sheshanthShettyun/quickshell-clipboard.git \
  ~/.config/quickshell/clipboard

# 2. Run persistently (add to your Hyprland startup)
qs -c clipboard -d

# 3. Bind a key to toggle (Hyprland example, SUPER+V)
bind = SUPER, V, exec, qs -c clipboard ipc call clipboard toggle
```

Make sure `cliphist` is collecting history, e.g. on Hyprland start:

```sh
wl-paste --type text --watch cliphist store
wl-paste --type image --watch cliphist store
```

## IPC

| Command                                    | Effect              |
| ------------------------------------------ | ------------------- |
| `qs -c clipboard ipc call clipboard toggle`  | toggle panel        |
| `qs -c clipboard ipc call clipboard open`    | open panel          |
| `qs -c clipboard ipc call clipboard close`   | close panel         |
| `qs -c clipboard ipc call clipboard refresh` | refresh from cliphist |

## Notes

- Binary clipboard data never passes through QML — all decode/copy/delete
  happens in `sh` pipelines; QML only sees text previews and file paths.
- Thumbnails live under `~/.cache/clipboard-panel/thumbs/<run-id>/`.
- `Esc` closes the panel. The UI font is a single `uiFont` property in
  `ClipboardPanel.qml` (passed down to rows).
