# rezfish window management: issues list

Goal: replace Magnet, and add Omarchy/Hyprland-style splitting on demand, while leaving macOS window behavior untouched unless a rezfish chord is used. No workspaces; macOS Spaces already covers that. Just window management.

Constraints and preferences:

- Keyboard first. Keep Magnet's stock ⌃⌥ chord map so muscle memory carries over.
- Gaps everywhere: space around every window so the wallpaper shows through, easy to change live.
- Multiple displays are common (2-3), not always. Throwing a window between screens must be one chord.
- Public APIs only. Accessibility permission is acceptable. No SIP changes, no private APIs.

## Foundation

### 1. Accessibility window layer

Read, move, resize, raise, and focus other apps' windows via `AXUIElement`. Observe window created/destroyed/moved/focused per app with `AXObserver` plus `NSWorkspace` app launch/terminate notifications. Run AX calls off the main thread with timeouts so a hung app doesn't freeze rezfish (AeroSpace does thread-per-app for this reason). Handle apps that refuse a size (minimum sizes) by reading back the actual frame after setting it.

Prompt for Accessibility permission on first use of a window chord, not at launch, so the resolution switcher keeps working without it.

### 2. Stable code signature for development

TCC ties the Accessibility grant to the code signature. `build.sh` ad-hoc signs, and an ad-hoc signature changes every build, so the permission would be revoked on each rebuild. Use a self-signed certificate (or a real Developer ID) in `build.sh` so the grant survives rebuilds.

### 3. Hotkey table

`HotKey.swift` registers one Carbon hotkey. Generalize to a table of chords mapped to actions, with the Magnet defaults below as the initial map. Carbon `RegisterEventHotKey` is fine; no Accessibility needed for hotkeys.

### 4. Overlay window

A transparent, click-through `NSWindow` per display for showing tile rectangles, snap previews, and the grid picker. Brief fade after a layout change. Reused by issues 8, 12, 13.

## Gaps

### 5. Gap model

Two values like Hyprland: `outer` (window to screen edge; allow per-side values so the menu bar side can differ) and `inner` (window to window). Defaults 10 / 5 (Omarchy's `gaps_out` / `gaps_in`). Applied to every frame rezfish sets, snap zones included, so "left half" means "left half minus gaps". Stored per display UUID in `Prefs`.

### 6. Live gap tuning

Chords to grow and shrink gaps in steps, and a chord to toggle gaps to zero and back (yabai's `space --toggle gap`). Persist per display. No settings window needed to tune.

### 7. Smart gaps

Toggle: when a display has a single managed window, either fill the screen or keep the gap (Amethyst `smart-window-margins`). Default keep the gap, since the wallpaper peeking through is the point.

## Magnet replacement

### 8. Snap commands with the Magnet chord map

| Chord | Action |
| --- | --- |
| ⌃⌥← / → / ↑ / ↓ | left / right / top / bottom half |
| ⌃⌥U / I / J / K | top-left / top-right / bottom-left / bottom-right quarter |
| ⌃⌥D / F / G | left / center / right third |
| ⌃⌥E / T / Y | left / center / right two-thirds |
| ⌃⌥Return | maximize (respecting gaps) |
| ⌃⌥C | center, no resize |
| ⌃⌥Backspace | restore pre-snap frame |
| ⌃⌥⌘← / → | previous / next display |

Sixths can wait. Every action shows briefly in the overlay.

### 9. Restore previous frame

Remember each window's frame before rezfish first touches it, keyed by window, and restore on ⌃⌥Backspace. Magnet's `restoreToOriginalSize` behavior.

### 10. Cycle on repeat

Repeating the same chord walks a sequence and remembers position per window (Rectangle cycling, Loop cycles). Example: ⌃⌥← walks left half → left third → left two-thirds. Shift reverses. Sequences configurable per chord.

### 11. Menu bar entries

Add a Window section to the existing menu listing snap actions with their chords, so the menu doubles as a cheat sheet like Magnet's.

## Zones and layouts

### 12. Zones by example

Chord to save the focused window's current frame as zone N for the current display (BetterSnapTool custom snap areas, Mosaic Advanced layouts). Chord N applies it. Gaps are applied on top so zones stay clean when gap values change. Stored per display UUID. Optional later: draggable bubbles on the overlay for mouse users.

### 13. Quick layout grid

Chord shows a grid overlay (default 6×4, configurable); drag or arrow-key a rectangle; the window takes that region. One-off, nothing saved (Mosaic Quick Layout, Moom grid).

### 14. Any-windows layouts

Save the frames of the N most recent windows as a named layout and reapply to whatever N windows are most recent (Moom "any windows"). Reapply automatically when the display set changes so undocking and redocking puts things back. Start with two- and three-window layouts.

## Hyprland-style splitting (no workspaces)

### 15. Split on demand

Chord divides the focused window's frame between it and the next most recently focused window on the same display. New window goes right or bottom (Omarchy sets `force_split = 2`, `preserve_split = true`), orientation chosen by the frame's aspect (wider than tall splits side by side). Gaps applied. Repeat on either window to subdivide. This builds a binary tree per display like Hyprland dwindle, but only for windows the user has explicitly split. Untouched windows stay floating like normal macOS.

### 16. Tree maintenance

When a managed window closes or is unmanaged, its sibling takes the space. When a managed window is moved or resized by the mouse, either drop it from the tree (simplest) or adjust the split ratio (Hyprland `resize_on_border` behavior). Start with drop.

### 17. Tree operations

- Focus by direction (Super+arrows in Omarchy).
- Swap by direction (Super+Shift+arrows).
- Toggle split orientation of the focused node (Super+J).
- Resize split ratio, fine and coarse steps (Omarchy Quattro added ±25px / ±100px tiers).
- Float: remove the window from the tree, keep its frame (Super+T).
- Fill: focused window temporarily takes the whole display, chord again to return (Super+F).

### 18. Optional tiled desktop mode

Per-display toggle: when on, every new window on that display is inserted into the tree at the focused node (true Omarchy behavior). When off, only explicit splits are managed. Off by default. Depends on issue 1's window-created observation. Float small windows and a per-app float list (Amethyst `float-small-windows`, `floating`) so dialogs don't get tiled.

## Multi-display

### 19. Throw by direction

Chords for left / right / up / down display in addition to next / previous. Resize proportionally on arrival so a half stays a half on a differently sized display (Moom "resize proportionally"). A window that was in a tree leaves it on departure and, if the target display has a tree and the window was tiled, joins at the focused node.

### 20. Per-display everything

Gaps, zones, layouts, tree, and cycle state are keyed by display UUID via the existing `Prefs` scheme so they survive unplugging and replugging.

## Explicitly not planned

- Workspaces or Spaces control. macOS Spaces stays as is.
- Drag-to-edge snapping. macOS does this natively since Sequoia.
- Radial menus, hover palettes, trackpad gestures, Touch Bar.
- Auto-tiling every new window by default.

## Chord layering

- ⌃⌥ + key: Magnet-equivalent snaps (issue 8), zones 1-9 (issue 12).
- ⌃⌥⇧ + key: split family (issues 15, 17), save zone N (issue 12).
- ⌃⌥⌘ + key: displays (issues 8, 19), gap grow/shrink/toggle (issue 6), quick grid (issue 13).
- ⌃⌥⌘R stays the resolution toggle.

## Research sources

- Magnet: https://magnet.crowdcafe.com/ and the local `com.crowdcafe.windowmagnet` preferences (stock ⌃⌥ map, 24×12 grid, 6px padding, restore on).
- BetterSnapTool: https://folivora.ai/bettersnaptool/
- Mosaic: https://lightpillar.com/mosaic-detailed.html
- Rectangle / Rectangle Pro: https://rectangleapp.com/pro and https://github.com/rxhanson/RectanglePro-Community
- Moom: https://manytricks.com/moom/help/customactions.html
- Loop: https://github.com/MrKai77/Loop
- Amethyst: https://github.com/ianyh/Amethyst/blob/development/docs/configuration-files.md
- yabai: https://github.com/koekeishiya/yabai/blob/master/doc/yabai.asciidoc
- AeroSpace: https://github.com/nikitabobko/AeroSpace/
- Hyprland dwindle: https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/
- Hyprland variables (gaps): https://wiki.hypr.land/Configuring/Variables/
- Omarchy look and feel defaults: https://github.com/omacom/omarchy/blob/master/default/hypr/looknfeel.conf
- Omarchy navigation manual: https://omarchy.org/manual/navigation/
- Omarchy 4 "Quattro" release: https://github.com/omacom/omarchy/releases/tag/v4.0.0
- Apple native tiling shortcuts: https://support.apple.com/guide/mac-help/mac-window-tiling-icons-keyboard-shortcuts-mchl9674d0b0/mac
- The listicle that started this: https://ioshacker.com/apps/best-window-manager-tools-for-mac
