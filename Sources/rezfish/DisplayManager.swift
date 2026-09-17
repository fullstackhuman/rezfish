import AppKit
import CoreGraphics

struct DisplayMode: Hashable {
    let cg: CGDisplayMode
    let width: Int
    let height: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let refresh: Double
    let modeID: Int32

    var isHiDPI: Bool { pixelWidth > width }

    /// Stable key for favorites/previous, independent of CG mode IDs.
    var key: String { "\(width)x\(height)@\(Int(refresh.rounded()))\(isHiDPI ? "h" : "")" }

    var label: String {
        var s = "\(width) × \(height)"
        if refresh > 0 { s += " @ \(Int(refresh.rounded())) Hz" }
        if isHiDPI { s += "  HiDPI" }
        return s
    }

    init(_ cg: CGDisplayMode) {
        self.cg = cg
        width = cg.width
        height = cg.height
        pixelWidth = cg.pixelWidth
        pixelHeight = cg.pixelHeight
        refresh = cg.refreshRate
        modeID = cg.ioDisplayModeID
    }

    static func == (a: DisplayMode, b: DisplayMode) -> Bool { a.modeID == b.modeID }
    func hash(into h: inout Hasher) { h.combine(modeID) }
}

struct Display {
    let id: CGDirectDisplayID
    let uuid: String
    let name: String
    let isMain: Bool
    let modes: [DisplayMode]
    let current: DisplayMode?
    /// True when the screen has a camera housing (notch) cut into it.
    let hasNotch: Bool
    /// Physical panel aspect (w/h), used to tell full-panel modes from below-the-notch modes.
    let panelAspect: Double

    /// Full-panel mode: same aspect as the physical panel, so the menu bar wraps around the notch.
    /// Anything else on a notched display is letterboxed below the notch.
    func usesNotchArea(_ m: DisplayMode) -> Bool {
        hasNotch && abs(Double(m.width) / Double(m.height) - panelAspect) < 0.01
    }
}

enum DisplayManager {
    static func displays() -> [Display] {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)

        return ids.map { id in
            let modes = modes(for: id)
            let screen = screen(for: id)
            let notch = (screen?.safeAreaInsets.top ?? 0) > 0
            // Largest-pixel mode gives the panel's true aspect.
            let native = modes.max { $0.pixelWidth * $0.pixelHeight < $1.pixelWidth * $1.pixelHeight }
            let aspect = native.map { Double($0.pixelWidth) / Double($0.pixelHeight) } ?? 0
            return Display(
                id: id,
                uuid: uuid(for: id),
                name: screen?.localizedName ?? (CGDisplayIsBuiltin(id) != 0 ? "Built-in Display" : "Display \(id)"),
                isMain: CGDisplayIsMain(id) != 0,
                modes: modes,
                current: CGDisplayCopyDisplayMode(id).map(DisplayMode.init),
                hasNotch: notch,
                panelAspect: aspect
            )
        }
        .sorted { $0.isMain && !$1.isMain }
    }

    static func modes(for id: CGDirectDisplayID) -> [DisplayMode] {
        let opts = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
        guard let raw = CGDisplayCopyAllDisplayModes(id, opts) as? [CGDisplayMode] else { return [] }

        // Keep only desktop-usable modes; collapse duplicates that differ only in bit depth.
        var best: [String: DisplayMode] = [:]
        for cg in raw where cg.isUsableForDesktopGUI() {
            let m = DisplayMode(cg)
            let k = "\(m.width)x\(m.height)x\(m.pixelWidth)x\(m.pixelHeight)@\(Int(m.refresh.rounded()))"
            if best[k] == nil { best[k] = m }
        }
        return best.values.sorted {
            if $0.width != $1.width { return $0.width > $1.width }
            if $0.height != $1.height { return $0.height > $1.height }
            if $0.isHiDPI != $1.isHiDPI { return $0.isHiDPI }
            return $0.refresh > $1.refresh
        }
    }

    @discardableResult
    static func set(_ mode: DisplayMode, on id: CGDirectDisplayID) -> Bool {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { return false }
        guard CGConfigureDisplayWithDisplayMode(config, id, mode.cg, nil) == .success else {
            CGCancelDisplayConfiguration(config)
            return false
        }
        return CGCompleteDisplayConfiguration(config, .permanently) == .success
    }

    static func uuid(for id: CGDirectDisplayID) -> String {
        guard let u = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return "\(id)" }
        return CFUUIDCreateString(nil, u) as String
    }

    static func screen(for id: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == id
        }
    }
}
