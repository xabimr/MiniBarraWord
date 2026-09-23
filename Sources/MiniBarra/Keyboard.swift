import AppKit
import ApplicationServices

/// Atajos que se envían a Word como pulsaciones (requiere permiso de Accesibilidad).
enum Keyboard {
    // Códigos de tecla físicos (posición ANSI; valen para el teclado español).
    static let keyA: CGKeyCode = 0x00
    static let keyD: CGKeyCode = 0x02
    static let keyX: CGKeyCode = 0x07
    static let keyC: CGKeyCode = 0x08
    static let keyV: CGKeyCode = 0x09
    static let keyM: CGKeyCode = 0x2E
    static let escape: CGKeyCode = 0x35

    /// Momento del último envío; el detector ignora las teclas que llegan justo después.
    private(set) static var lastSent = Date.distantPast

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestTrust() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func send(_ key: CGKeyCode, _ flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else { return }
        down.flags = flags
        up.flags = flags
        lastSent = Date()
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }

    static func newComment() { send(keyA, [.maskCommand, .maskAlternate]) }
    static func cut() { send(keyX, .maskCommand) }
    static func copy() { send(keyC, .maskCommand) }
    static func fontDialog() { send(keyD, .maskCommand) }
    static func paragraphDialog() { send(keyM, [.maskCommand, .maskAlternate]) }
}
