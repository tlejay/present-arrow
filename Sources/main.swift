// Present Arrow — hold Option and move the mouse to draw an arrow on screen.
// The arrow's tail stays where Option was pressed; the head follows the cursor.
// Releasing Option hides the arrow. Lives in the menu bar (no Dock icon).
//
// Input is read by polling NSEvent.modifierFlags / NSEvent.mouseLocation,
// which needs no Accessibility or Input Monitoring permission.

import AppKit
import ServiceManagement

// MARK: - Settings

enum Prefs {
    static let d = UserDefaults.standard

    static var enabled: Bool {
        get { d.object(forKey: "enabled") as? Bool ?? true }
        set { d.set(newValue, forKey: "enabled") }
    }
    static var colorName: String {
        get { d.string(forKey: "color") ?? "Red" }
        set { d.set(newValue, forKey: "color") }
    }
    static var thickness: CGFloat {
        get { CGFloat(d.object(forKey: "thickness") as? Double ?? 8) }
        set { d.set(Double(newValue), forKey: "thickness") }
    }
}

let palette: [(String, NSColor)] = [
    ("Red", NSColor(srgbRed: 1.00, green: 0.23, blue: 0.19, alpha: 1)),
    ("Yellow", NSColor(srgbRed: 1.00, green: 0.80, blue: 0.00, alpha: 1)),
    ("Green", NSColor(srgbRed: 0.20, green: 0.84, blue: 0.29, alpha: 1)),
    ("Blue", NSColor(srgbRed: 0.04, green: 0.52, blue: 1.00, alpha: 1)),
    ("Pink", NSColor(srgbRed: 1.00, green: 0.18, blue: 0.57, alpha: 1)),
    ("White", .white),
]

func currentColor() -> NSColor {
    palette.first { $0.0 == Prefs.colorName }?.1 ?? palette[0].1
}

// MARK: - Arrow geometry

/// Builds a closed arrow outline (shaft + head) from `a` (tail) to `b` (head).
func arrowPath(from a: CGPoint, to b: CGPoint, width w: CGFloat) -> CGPath? {
    let dx = b.x - a.x, dy = b.y - a.y
    let len = hypot(dx, dy)
    guard len > 1 else { return nil }

    let headLen = min(max(w * 4.2, 22), len)
    let headHalf = max(w * 2.4, 13)
    let shaftHalf = w / 2
    let shaftLen = len - headLen * 0.85

    // Build along +x axis, then rotate/translate to the real direction.
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 0, y: -shaftHalf))
    p.addLine(to: CGPoint(x: shaftLen, y: -shaftHalf))
    p.addLine(to: CGPoint(x: len - headLen, y: -headHalf))
    p.addLine(to: CGPoint(x: len, y: 0))
    p.addLine(to: CGPoint(x: len - headLen, y: headHalf))
    p.addLine(to: CGPoint(x: shaftLen, y: shaftHalf))
    p.addLine(to: CGPoint(x: 0, y: shaftHalf))
    p.closeSubpath()

    var t = CGAffineTransform(translationX: a.x, y: a.y).rotated(by: atan2(dy, dx))
    return p.copy(using: &t)
}

// MARK: - Overlay (one transparent click-through window per screen)

final class ArrowView: NSView {
    let shape = CAShapeLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        shape.shadowColor = NSColor.black.cgColor
        shape.shadowOpacity = 0.4
        shape.shadowRadius = 5
        shape.shadowOffset = CGSize(width: 0, height: -2)
        layer?.addSublayer(shape)
    }
    required init?(coder: NSCoder) { fatalError() }

    func update(path: CGPath?, color: NSColor) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.path = path
        shape.fillColor = color.cgColor
        CATransaction.commit()
    }
}

final class OverlayWindow: NSWindow {
    let arrowView: ArrowView

    init(screen: NSScreen) {
        arrowView = ArrowView(frame: NSRect(origin: .zero, size: screen.frame.size))
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        contentView = arrowView
        setFrame(screen.frame, display: false)
    }
}

// MARK: - Controller

final class ArrowController {
    private var windows: [OverlayWindow] = []
    private var timer: Timer?
    private var anchor: CGPoint?        // global coords where Option went down
    private var visible = false
    private let minDistance: CGFloat = 12 // ignore tiny moves (e.g. typing ⌥ shortcuts)

    init() {
        rebuildWindows()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.rebuildWindows() }

        let t = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { OverlayWindow(screen: $0) }
        hide()
    }

    private func tick() {
        let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let optionOnly = flags.contains(.option)
            && !flags.contains(.command) && !flags.contains(.control) && !flags.contains(.shift)

        guard Prefs.enabled, optionOnly else {
            anchor = nil
            if visible { hide() }
            return
        }

        let mouse = NSEvent.mouseLocation
        if anchor == nil { anchor = mouse }
        guard let a = anchor else { return }

        if !visible && hypot(mouse.x - a.x, mouse.y - a.y) < minDistance { return }
        draw(from: a, to: mouse)
    }

    private func draw(from a: CGPoint, to b: CGPoint) {
        let color = currentColor()
        let width = Prefs.thickness
        for w in windows {
            let o = w.frame.origin
            let path = arrowPath(from: CGPoint(x: a.x - o.x, y: a.y - o.y),
                                 to: CGPoint(x: b.x - o.x, y: b.y - o.y), width: width)
            w.arrowView.update(path: path, color: color)
            if !visible { w.orderFrontRegardless() }
        }
        visible = true
    }

    private func hide() {
        for w in windows {
            w.arrowView.update(path: nil, color: .clear)
            w.orderOut(nil)
        }
        visible = false
    }
}

// MARK: - Menu bar

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var controller: ArrowController!

    func applicationDidFinishLaunching(_ n: Notification) {
        controller = ArrowController()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func updateIcon() {
        let name = Prefs.enabled ? "arrow.up.right.circle.fill" : "arrow.up.right.circle"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Present Arrow")
        img?.isTemplate = true
        statusItem.button?.image = img
    }

    // Rebuild the menu each time it opens so check marks are always current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let hint = NSMenuItem(title: "Hold ⌥ Option + move mouse to point", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        // Window-only sharing captures just that window, so the overlay can't be seen.
        let share = NSMenuItem(title: "Share your entire screen, not one window", action: nil, keyEquivalent: "")
        share.isEnabled = false
        menu.addItem(share)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        toggle.state = Prefs.enabled ? .on : .off
        menu.addItem(toggle)

        let colorMenu = NSMenu()
        for (name, color) in palette {
            let it = NSMenuItem(title: name, action: #selector(pickColor(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = name
            it.state = Prefs.colorName == name ? .on : .off
            it.image = swatch(color)
            colorMenu.addItem(it)
        }
        let colorItem = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        colorItem.submenu = colorMenu
        menu.addItem(colorItem)

        let sizeMenu = NSMenu()
        for (name, v) in [("Thin", 5.0), ("Medium", 8.0), ("Thick", 12.0), ("Huge", 18.0)] {
            let it = NSMenuItem(title: name, action: #selector(pickSize(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = v
            it.state = abs(Double(Prefs.thickness) - v) < 0.1 ? .on : .off
            sizeMenu.addItem(it)
        }
        let sizeItem = NSMenuItem(title: "Thickness", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(.separator())
        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Present Arrow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    func swatch(_ c: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 12, height: 12), flipped: false) { r in
            c.setFill()
            NSBezierPath(ovalIn: r.insetBy(dx: 0.5, dy: 0.5)).fill()
            NSColor.gray.setStroke()
            NSBezierPath(ovalIn: r.insetBy(dx: 0.5, dy: 0.5)).stroke()
            return true
        }
    }

    @objc func toggleEnabled() { Prefs.enabled.toggle(); updateIcon() }
    @objc func pickColor(_ s: NSMenuItem) { if let n = s.representedObject as? String { Prefs.colorName = n } }
    @objc func pickSize(_ s: NSMenuItem) { if let v = s.representedObject as? Double { Prefs.thickness = CGFloat(v) } }
    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            NSLog("Present Arrow: login item error: \(error)")
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
