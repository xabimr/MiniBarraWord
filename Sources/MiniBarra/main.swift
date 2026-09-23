import AppKit
import ServiceManagement

// `MiniBarra --check` compila todos los AppleScript contra el diccionario de
// Word sin ejecutarlos (no toca ningún documento).
if CommandLine.arguments.contains("--check") {
    let failures = WordBridge().compileCheck()
    print(failures.isEmpty ? "OK: \(WordBridge.allScriptsForCheck().count) scripts compilan" : failures.joined(separator: "\n"))
    exit(failures.isEmpty ? 0 : 1)
}

if let i = CommandLine.arguments.firstIndex(of: "--preview"), i + 1 < CommandLine.arguments.count {
    _ = NSApplication.shared
    let path = CommandLine.arguments[i + 1]
    let toolbar = Toolbar(word: WordBridge())
    try? toolbar.snapshot(dark: false)?.write(to: URL(fileURLWithPath: path + "-claro.png"))
    try? toolbar.snapshot(dark: true)?.write(to: URL(fileURLWithPath: path + "-oscuro.png"))
    exit(0)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let word = WordBridge()
    private let watcher = SelectionWatcher()
    private var toolbar: Toolbar!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        toolbar = Toolbar(word: word)

        watcher.onSelectionGesture = { [unowned self] start, end in
            guard Settings.enabled else { return }
            toolbar.selectionChanged(start: start, end: end)
        }
        watcher.onDismiss = { [unowned self] in toolbar.hide() }
        watcher.onEscape = { [unowned self] in toolbar.escape() }
        watcher.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Icons.symbol("textformat", size: 13)
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = "MiniBarra para Word"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        if !Keyboard.isTrusted { Keyboard.requestTrust() }
    }
}

extension AppDelegate: NSMenuDelegate {
    /// El menú de la barra de menús se reconstruye cada vez para reflejar el estado.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let enabled = ClosureMenuItem(title: "Barra activada") { [unowned self] in
            Settings.enabled.toggle()
            if !Settings.enabled { toolbar.hide() }
        }
        enabled.state = Settings.enabled ? .on : .off
        menu.addItem(enabled)

        let doubleClick = ClosureMenuItem(title: "Mostrar también con doble clic") {
            Settings.showOnDoubleClick.toggle()
        }
        doubleClick.state = Settings.showOnDoubleClick ? .on : .off
        menu.addItem(doubleClick)

        let login = ClosureMenuItem(title: "Abrir al iniciar sesión") {
            let service = SMAppService.mainApp
            do {
                if service.status == .enabled { try service.unregister() } else { try service.register() }
            } catch {
                NSLog("MiniBarra: no se pudo cambiar el inicio de sesión: %@", "\(error)")
            }
        }
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        if Keyboard.isTrusted {
            let ok = NSMenuItem(title: "Permiso de Accesibilidad concedido", action: nil, keyEquivalent: "")
            ok.image = Icons.symbol("checkmark.circle", size: 12)
            ok.isEnabled = false
            menu.addItem(ok)
        } else {
            menu.addItem(ClosureMenuItem(title: "Conceder permiso de Accesibilidad…") {
                Keyboard.requestTrust()
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            })
        }
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "Salir de MiniBarra") { NSApp.terminate(nil) })
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
