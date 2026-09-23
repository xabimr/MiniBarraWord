import AppKit
import ApplicationServices

/// Vigila el ratón y el teclado a nivel global y avisa cuando el usuario
/// termina un gesto de selección en Word (arrastre, doble/triple clic o
/// mayúsculas + clic), o cuando hace algo que debe ocultar la barra.
final class SelectionWatcher {
    var onSelectionGesture: ((_ start: NSPoint, _ end: NSPoint) -> Void)?
    var onDismiss: (() -> Void)?
    var onEscape: (() -> Void)?

    private var monitors: [Any] = []
    private var keyMonitor: Any?
    private var downPoint: NSPoint = .zero
    private var downOnChrome = false
    private var trustTimer: Timer?

    /// Roles de accesibilidad que corresponden a la interfaz de Word (cinta,
    /// barras de desplazamiento…) y no al texto del documento.
    private static let chromeRoles: Set<String> = [
        "AXButton", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXMenuButton",
        "AXComboBox", "AXTextField", "AXSlider", "AXScrollBar", "AXValueIndicator",
        "AXSplitter", "AXTabGroup", "AXToolbar", "AXMenuBar", "AXMenuBarItem",
        "AXIncrementor", "AXDisclosureTriangle", "AXSearchField",
    ]

    func start() {
        let mask: [(NSEvent.EventTypeMask, (NSEvent) -> Void)] = [
            (.leftMouseDown, { [weak self] e in self?.mouseDown(e) }),
            (.leftMouseUp, { [weak self] e in self?.mouseUp(e) }),
            (.rightMouseDown, { [weak self] _ in self?.onDismiss?() }),
            (.scrollWheel, { [weak self] _ in self?.onDismiss?() }),
        ]
        for (m, handler) in mask {
            if let mon = NSEvent.addGlobalMonitorForEvents(matching: m, handler: handler) {
                monitors.append(mon)
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)

        installKeyMonitorWhenTrusted()
    }

    /// El monitor de teclado solo funciona con permiso de Accesibilidad, que el
    /// usuario puede conceder más tarde: se reintenta cada dos segundos.
    private func installKeyMonitorWhenTrusted() {
        if Keyboard.isTrusted {
            installKeyMonitor()
            return
        }
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
            guard Keyboard.isTrusted else { return }
            t.invalidate()
            self?.installKeyMonitor()
        }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] e in
            // Las pulsaciones que envía la propia barra no la cierran.
            if Date().timeIntervalSince(Keyboard.lastSent) < 0.3 { return }
            if e.keyCode == Keyboard.escape { self?.onEscape?() }
            self?.onDismiss?()
        }
    }

    @objc private func appActivated(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        if app?.bundleIdentifier != WordBridge.bundleID && app != NSRunningApplication.current {
            onDismiss?()
        }
    }

    private var wordIsFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == WordBridge.bundleID
    }

    private func mouseDown(_ e: NSEvent) {
        downPoint = NSEvent.mouseLocation
        downOnChrome = wordIsFrontmost && Self.isChrome(at: downPoint)
        onDismiss?()
    }

    private func mouseUp(_ e: NSEvent) {
        guard wordIsFrontmost, !downOnChrome else { return }
        let up = NSEvent.mouseLocation
        let dragged = hypot(up.x - downPoint.x, up.y - downPoint.y) > 4
        let multiClick = e.clickCount >= 2 && Settings.showOnDoubleClick
        let shiftClick = e.modifierFlags.contains(.shift)
        guard dragged || multiClick || shiftClick else { return }
        let start = downPoint
        // Pequeña espera para que Word termine de actualizar la selección.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            self?.onSelectionGesture?(start, up)
        }
    }

    private static func isChrome(at p: NSPoint) -> Bool {
        guard Keyboard.isTrusted, let primary = NSScreen.screens.first else { return false }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.2)
        var element: AXUIElement?
        // Accesibilidad usa origen arriba a la izquierda de la pantalla principal.
        let err = AXUIElementCopyElementAtPosition(
            system, Float(p.x), Float(primary.frame.maxY - p.y), &element)
        guard err == .success, let element else { return false }
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        return chromeRoles.contains(role as? String ?? "")
    }
}
