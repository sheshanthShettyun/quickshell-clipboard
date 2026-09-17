# quickshell-clipboard

A standalone [Quickshell](https://quickshell.org/) clipboard shelf backed by
[cliphist](https://github.com/sentriz/cliphist). Built for Hyprland alongside
the Caelestia shell, but it runs as its own independent config so shell
updates can't break it. Edge-Drop-inspired UX (filter chips, preview flyout)
in Caelestia's visual language.

## Features

- **Image thumbnails** — image entries decoded lazily to a thumbnail cache
- **Wipe-proof pins** — pinned entries stored in
  `~/.local/share/clipboard-panel/pins.json`, survive `cliphist wipe`
- **Search** — type to filter history + pins (`Enter` copies the top match)
- **Category chips** — All / Text / Images / Links / Code / Pinned with live
  counts, combined with search
- **Preview flyout** — single-click a card for full scrollable text or
  full-size image plus Copy / Pin / Delete; double-click (or `Enter`) copies
  instantly; `Esc` steps back out
- **Content-type icons** — Material Symbols glyphs per kind
  (text / link / code / image thumbnail), same icon language as Caelestia
- **Per-row delete**, **Clear history** pill (pins survive it)
- **Live Caelestia theming** — reads the shell's dynamic `scheme.json`, so
  the panel re-themes itself on wallpaper / light-dark changes
- **Caelestia motion** — elastic-drop entrance, StateLayer hover (ink at 8%,
  200ms), press ripple, instant close
- **Opens on the focused monitor**, docked to the screen edge (square edge,
  6px gaps like the sidebar drawers), Google Sans Flex (loaded from the
  shell's own font asset) + `Text.NativeRendering` like the Caelestia bars
  and panels

## Files

| File                   | Role                                                |
| ---------------------- | --------------------------------------------------- |
| `shell.qml`            | `ShellRoot`, per-screen panel windows, IPC targets  |
| `ClipboardService.qml` | cliphist backend (list / decode / delete / copy) + content-kind detection |
| `PinsStore.qml`        | pinned entries JSON store                           |
| `ClipboardPanel.qml`   | shelf window: search, chips, pinned + history, preview overlay |
| `ClipRow.qml`          | one card: icon/thumbnail + text + pin/delete        |
| `Theme.qml`            | live bridge to the Caelestia dynamic scheme         |

## Dependencies

- `quickshell`
- `cliphist`
- `wl-clipboard` (`wl-copy`)
- Hyprland (window + keybind integration)
- Fonts: Google Sans Flex (loaded from the Caelestia shell's font asset), Material Symbols Rounded (same as the Caelestia shell)

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

| Command                                              | Effect                    |
| ---------------------------------------------------- | ------------------------- |
| `qs -c clipboard ipc call clipboard toggle`          | toggle panel              |
| `qs -c clipboard ipc call clipboard open`            | open panel                |
| `qs -c clipboard ipc call clipboard close`           | close panel               |
| `qs -c clipboard ipc call clipboard refresh`         | refresh from cliphist     |
| `qs -c clipboard ipc call clipboardUi setFilter <k>` | set category (`all`, `text`, `images`, `links`, `code`, `pinned`) |
| `qs -c clipboard ipc call clipboardUi previewTop`    | preview the top history entry |

## Notes

- Binary clipboard data never passes through QML — all decode/copy/delete
  happens in `sh` pipelines; QML only sees text previews and file paths.
- Thumbnails live under `~/.cache/clipboard-panel/thumbs/<run-id>/`.
- `Esc` steps back from preview, then closes the panel. The UI font is a
  single `uiFont` property in `ClipboardPanel.qml` (passed down to rows).
- Row highlights are panel-owned state (reset on close/refresh), so they
  can never stick like per-delegate hover does.
