import AppKit
import Carbon
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = StatusIcon.make()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // ⌃⌥⌘R toggles the main display between its current and previous mode.
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_R),
                        modifiers: UInt32(controlKey | optionKey | cmdKey)) { [weak self] in
            self?.togglePrevious()
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let displays = DisplayManager.displays()

        if displays.count == 1, let d = displays.first {
            addModes(for: d, to: menu)
        } else {
            for d in displays {
                let sub = NSMenu()
                addModes(for: d, to: sub)
                let item = NSMenuItem(title: title(for: d), action: nil, keyEquivalent: "")
                item.submenu = sub
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let prev = NSMenuItem(title: "Toggle Previous Resolution", action: #selector(togglePrevious), keyEquivalent: "r")
        prev.keyEquivalentModifierMask = [.control, .option, .command]
        prev.target = self
        menu.addItem(prev)

        let all = NSMenuItem(title: "Show All Modes", action: #selector(toggleShowAll), keyEquivalent: "")
        all.state = Prefs.showAllModes ? .on : .off
        all.target = self
        menu.addItem(all)

        let login = NSMenuItem(title: "Start at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        login.target = self
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit rezfish", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func title(for d: Display) -> String {
        d.isMain ? "\(d.name) (Main)" : d.name
    }

    private func addModes(for d: Display, to menu: NSMenu) {
        let header = NSMenuItem(title: title(for: d), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let favs = Prefs.favorites(for: d.uuid)
        let favModes = d.modes.filter { favs.contains($0.key) }
        let rest = Prefs.showAllModes ? d.modes : d.modes.filter { m in
            // Default view: hide refresh-rate variants and modes below 1024 wide.
            m.width >= 1024 && m.refresh == (d.modes.first { $0.width == m.width && $0.height == m.height && $0.isHiDPI == m.isHiDPI }?.refresh ?? m.refresh)
        }

        if !favModes.isEmpty {
            for m in favModes { addMode(m, display: d, to: menu, isFav: true) }
            menu.addItem(.separator())
        }
        let others = rest.filter { !favModes.contains($0) }
        if d.hasNotch {
            addSection("Around the notch (full panel)", others.filter { d.usesNotchArea($0) }, display: d, to: menu)
            addSection("Below the notch (16:10)", others.filter { !d.usesNotchArea($0) }, display: d, to: menu)
        } else {
            for m in others { addMode(m, display: d, to: menu, isFav: false) }
        }
    }

    private func addSection(_ title: String, _ modes: [DisplayMode], display d: Display, to menu: NSMenu) {
        guard !modes.isEmpty else { return }
        if #available(macOS 14, *) {
            menu.addItem(.sectionHeader(title: title))
        } else {
            let h = NSMenuItem(title: title, action: nil, keyEquivalent: ""); h.isEnabled = false; menu.addItem(h)
        }
        for m in modes { addMode(m, display: d, to: menu, isFav: false) }
    }

    private func addMode(_ m: DisplayMode, display d: Display, to menu: NSMenu, isFav: Bool) {
        var label = m.label
        if isFav, d.hasNotch { label += d.usesNotchArea(m) ? "  · around notch" : "  · below notch" }
        let item = NSMenuItem(title: (isFav ? "★ " : "") + label, action: #selector(pick(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = Pick(display: d, mode: m)
        item.state = m == d.current ? .on : .off
        item.indentationLevel = 1
        menu.addItem(item)

        // Option-click: add/remove favorite.
        let alt = NSMenuItem(title: (isFav ? "Unfavorite " : "Favorite ") + m.label, action: #selector(toggleFav(_:)), keyEquivalent: "")
        alt.target = self
        alt.representedObject = Pick(display: d, mode: m)
        alt.isAlternate = true
        alt.keyEquivalentModifierMask = .option
        alt.indentationLevel = 1
        menu.addItem(alt)
    }

    // MARK: Actions

    private final class Pick: NSObject {
        let display: Display; let mode: DisplayMode
        init(display: Display, mode: DisplayMode) { self.display = display; self.mode = mode }
    }

    @objc private func pick(_ sender: NSMenuItem) {
        guard let p = sender.representedObject as? Pick else { return }
        apply(p.mode, to: p.display)
    }

    @objc private func toggleFav(_ sender: NSMenuItem) {
        guard let p = sender.representedObject as? Pick else { return }
        Prefs.toggleFavorite(p.mode.key, for: p.display.uuid)
    }

    @objc private func togglePrevious() {
        guard let d = DisplayManager.displays().first(where: { $0.isMain }),
              let prevKey = Prefs.previous(for: d.uuid),
              let m = d.modes.first(where: { $0.key == prevKey }) else { NSSound.beep(); return }
        apply(m, to: d)
    }

    @objc private func toggleShowAll() { Prefs.showAllModes.toggle() }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            alert("Couldn't change login item", "\(error.localizedDescription)\n\nrezfish must be run from an .app bundle in /Applications for this to work.")
        }
    }

    private func apply(_ m: DisplayMode, to d: Display) {
        guard m != d.current else { return }
        if let cur = d.current { Prefs.setPrevious(cur.key, for: d.uuid) }
        if !DisplayManager.set(m, on: d.id) {
            alert("Couldn't switch resolution", "\(d.name) refused \(m.label).")
        }
    }

    private func alert(_ title: String, _ text: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }
}
