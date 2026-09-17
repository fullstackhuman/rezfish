# rezfish

A macOS menu bar utility for switching display resolutions without opening System Settings.

Click the menu bar icon, pick a resolution, done. Same idea as ResolutionTab, which is still an Intel binary from 2012. rezfish is native Apple Silicon, uses only public APIs, and has no dependencies.

## Features

- Menu bar only, no Dock icon.
- Every desktop-usable mode per display, including HiDPI (Retina) and native-pixel modes.
- Multiple displays, with the main display marked.
- On notched MacBooks, modes are split into **Around the notch** (full panel) and **Below the notch** (16:10) sections.
- Favorites. To pin or unpin a mode, hold Option while you click it. Favorites appear at the top with a star.
- Toggle between the current and previous resolution with ⌃⌥⌘R. The shortcut is global and doesn't need Accessibility permission.
- **Show All Modes** reveals refresh-rate variants and small modes that are hidden by default.
- **Start at Login**.
- The menu rebuilds each time it opens, so hot-plugged displays appear without a restart.

## Install

rezfish requires Apple Silicon, macOS 14 or later, and the Xcode Command Line Tools. Xcode itself isn't required.

1. Clone the repo and build:

   ```sh
   gh repo clone fullstackhuman/rezfish && cd rezfish
   ./build.sh install
   ```

   The script builds the app, copies it to `/Applications/rezfish.app`, and launches it.

2. Optional: In the rezfish menu, click **Start at Login**.

If you copy the built app to another Mac instead of building there, the first launch is blocked because the app is ad-hoc signed. Either right-click the app and click **Open**, or clear the quarantine flag:

```sh
xattr -dr com.apple.quarantine /Applications/rezfish.app
```

## Test a change

To run a build without replacing the installed copy, quit the running app first. macOS allows one instance per bundle ID, so `open` on a second copy only activates the one already running.

```sh
pkill -x rezfish; ./build.sh && open dist/rezfish.app
```

When you're done, run `./build.sh install` to put the new version back in `/Applications`.

## How it works

Five Swift files. The app uses AppKit, CoreGraphics, Carbon for the hotkey, and ServiceManagement for the login item.

- `DisplayManager.swift` enumerates displays with `CGDisplayCopyAllDisplayModes`. It passes `kCGDisplayShowDuplicateLowResolutionModes` so HiDPI variants are included, and it switches modes with `CGConfigureDisplayWithDisplayMode`.
- `AppDelegate.swift` builds the `NSMenu` on demand.
- `Prefs.swift` stores favorites and the previous mode in `UserDefaults`, keyed by display UUID so they survive re-plugging.
- `HotKey.swift` registers the global shortcut with Carbon's `RegisterEventHotKey`.
- `StatusIcon.swift` draws the menu bar icon in code as a template image.
- `scripts/make-icon.swift` renders the same shape on goldenrod into `Resources/AppIcon.icns`. Run it with `swift scripts/make-icon.swift` after changing the icon.

## License

MIT
