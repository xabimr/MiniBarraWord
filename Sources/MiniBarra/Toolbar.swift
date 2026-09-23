import AppKit

/// Panel sin bordes que flota sobre Word sin robarle el foco.
final class ToolbarPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 600, height: 42),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// La barra de formato: construye los controles, los sincroniza con la
/// selección de Word y ejecuta las acciones.
final class Toolbar: NSObject {
    private let word: WordBridge
    private let panel = ToolbarPanel()
    private var state: SelectionState?

    private var fontButton: BarButton!
    private var sizeButton: BarButton!
    private var boldButton: BarButton!
    private var italicButton: BarButton!
    private var underlineButton: BarButton!
    private var colorButton: BarButton!
    private var highlightButton: BarButton!
    private var painterButton: BarButton!

    private var painterArmed = false { didSet { painterButton.isOn = painterArmed } }
    private var painterSticky = false
    private var fontMenu: NSMenu?

    private static let sizes: [Double] = [8, 9, 10, 10.5, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72]

    init(word: WordBridge) {
        self.word = word
        super.init()
        buildUI()
        NotificationCenter.default.addObserver(self, selector: #selector(colorPanelClosed(_:)),
                                               name: NSWindow.willCloseNotification, object: NSColorPanel.shared)
    }

    var isVisible: Bool { panel.isVisible }

    // MARK: - Construcción

    /// Disposición como la minibarra de Word para Windows: dos filas de controles
    /// a la izquierda y dos botones grandes (Estilos, Nuevo comentario) a la derecha.
    private func buildUI() {
        let letters = Icons.formatLetters

        // Fila 1: fuente, tamaño, aumentar/reducir y copiar formato.
        fontButton = BarButton(text: NSAttributedString(string: ""), width: 150, chevron: true, bordered: true, tooltip: "Fuente")
        fontButton.onClick = { [unowned self] _ in fontButton.popUp(makeFontMenu()) }

        sizeButton = BarButton(text: NSAttributedString(string: ""), width: 56, chevron: true, bordered: true, tooltip: "Tamaño de fuente")
        sizeButton.onClick = { [unowned self] _ in sizeButton.popUp(makeSizeMenu()) }

        let growButton = BarButton(image: Icons.fontStep(up: true), width: 30, tooltip: "Aumentar tamaño de fuente")
        growButton.onClick = { [unowned self] _ in stepSize(+1) }

        let shrinkButton = BarButton(image: Icons.fontStep(up: false), width: 30, tooltip: "Reducir tamaño de fuente")
        shrinkButton.onClick = { [unowned self] _ in stepSize(-1) }

        painterButton = BarButton(image: Icons.symbol("paintbrush.pointed", size: 14, fallback: "paintbrush"),
                                  width: 30, tooltip: "Copiar formato (doble clic para aplicarlo varias veces)")
        painterButton.onClick = { [unowned self] e in togglePainter(e) }

        // Fila 2: N K S, resaltado, color, viñetas y numeración.
        boldButton = BarButton(text: Icons.letter(letters.bold, bold: true), width: 28, tooltip: "Negrita (⌘B)")
        boldButton.onClick = { [unowned self] _ in perform { word.toggleBold() } }

        italicButton = BarButton(text: Icons.letter(letters.italic, italic: true), width: 28, tooltip: "Cursiva (⌘I)")
        italicButton.onClick = { [unowned self] _ in perform { word.toggleItalic() } }

        underlineButton = BarButton(text: Icons.letter(letters.underline, underline: true), width: 28, tooltip: "Subrayado (⌘U)")
        underlineButton.onClick = { [unowned self] _ in perform { word.toggleUnderline() } }

        highlightButton = BarButton(image: Icons.highlighter(currentHighlight?.color), width: 28, tooltip: "Color de resaltado")
        highlightButton.onClick = { [unowned self] _ in applyHighlight(currentHighlight) }
        let highlightMenuButton = chevronButton(tooltip: "Más colores de resaltado")
        highlightMenuButton.onClick = { [unowned self] _ in highlightMenuButton.popUp(makeHighlightMenu()) }

        colorButton = BarButton(image: Icons.fontColor(Settings.fontColor), width: 28, tooltip: "Color de fuente")
        colorButton.onClick = { [unowned self] _ in applyFontColor(Settings.fontColor) }
        let colorMenuButton = chevronButton(tooltip: "Más colores de fuente")
        colorMenuButton.onClick = { [unowned self] _ in colorMenuButton.popUp(makeFontColorMenu()) }

        let bulletsButton = BarButton(image: Icons.symbol("list.bullet", size: 15), width: 28, tooltip: "Viñetas")
        bulletsButton.onClick = { [unowned self] _ in perform { word.toggleBullets() } }
        let bulletsMenuButton = chevronButton(tooltip: "Opciones de lista")
        bulletsMenuButton.onClick = { [unowned self] _ in bulletsMenuButton.popUp(makeListMenu()) }

        let numberingButton = BarButton(image: Icons.symbol("list.number", size: 15), width: 28, tooltip: "Numeración")
        numberingButton.onClick = { [unowned self] _ in perform { word.toggleNumbering() } }
        let numberingMenuButton = chevronButton(tooltip: "Opciones de lista")
        numberingMenuButton.onClick = { [unowned self] _ in numberingMenuButton.popUp(makeListMenu()) }

        // Botones grandes.
        let stylesButton = BarButton(image: Icons.symbol("textformat", size: 21), caption: "Estilos",
                                     width: 66, height: 60, chevron: true, tooltip: "Estilos")
        stylesButton.onClick = { [unowned self] _ in stylesButton.popUp(makeStyleMenu()) }

        let commentButton = BarButton(image: Icons.symbol("plus.bubble", size: 21, fallback: "text.bubble"),
                                      caption: "Nuevo comentario", width: 84, height: 60, tooltip: "Nuevo comentario")
        commentButton.onClick = { [unowned self] _ in newComment() }

        let row1 = Self.row([fontButton, sizeButton, growButton, shrinkButton, painterButton], spacing: 3)
        let row2 = Self.row([boldButton, italicButton, underlineButton,
                             highlightButton, highlightMenuButton, colorButton, colorMenuButton,
                             bulletsButton, bulletsMenuButton, numberingButton, numberingMenuButton], spacing: 1)
        let rows = NSStackView(views: [row1, row2])
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 3

        let stack = Self.row([rows, BarSeparator(height: 60), stylesButton, BarSeparator(height: 60), commentButton], spacing: 2)
        stack.edgeInsets = NSEdgeInsets(top: 5, left: 6, bottom: 5, right: 6)

        let background = NSVisualEffectView()
        background.material = .popover
        background.state = .active
        background.blendingMode = .behindWindow
        background.wantsLayer = true
        background.layer?.cornerRadius = 8
        background.layer?.masksToBounds = true
        background.layer?.borderWidth = 0.5
        background.layer?.borderColor = NSColor.separatorColor.cgColor

        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        panel.contentView = background
        panel.setContentSize(stack.fittingSize)
    }

    private static func row(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = spacing
        return stack
    }

    private func chevronButton(tooltip: String) -> BarButton {
        BarButton(image: Icons.symbol("chevron.down", size: 8, weight: .semibold), width: 14, tooltip: tooltip)
    }

    // MARK: - Mostrar y ocultar

    /// Muestra la barra encima de la zona seleccionada (entre `start` y `end`,
    /// los puntos donde se pulsó y se soltó el ratón).
    func show(state: SelectionState, start: NSPoint, end: NSPoint) {
        update(with: state)
        let size = panel.frame.size
        let screen = NSScreen.screens.first { NSMouseInRect(end, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        var x = min(start.x, end.x) - 24
        var y = max(start.y, end.y) + 16
        if y + size.height > visible.maxY - 4 {
            y = min(start.y, end.y) - 24 - size.height
        }
        x = max(visible.minX + 8, min(x, visible.maxX - size.width - 8))
        y = max(visible.minY + 8, y)
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            panel.invalidateShadow()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                panel.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
    }

    /// Se llama al terminar una selección en Word.
    func selectionChanged(start: NSPoint, end: NSPoint) {
        if painterArmed {
            word.pasteFormat()
            if !painterSticky { painterArmed = false }
        }
        guard let state = word.selectionState() else { hide(); return }
        show(state: state, start: start, end: end)
    }

    func escape() {
        painterArmed = false
        painterSticky = false
        hide()
    }

    private func update(with state: SelectionState) {
        self.state = state
        fontButton.title = state.fontName
        sizeButton.title = state.fontSize.map(Self.formatSize) ?? ""
        boldButton.isOn = state.bold
        italicButton.isOn = state.italic
        underlineButton.isOn = state.underline
    }

    private static func formatSize(_ size: Double) -> String {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: size)) ?? "\(size)"
    }

    /// Ejecuta una acción sobre Word y resincroniza los botones.
    private func perform(_ action: () -> Void) {
        action()
        refresh()
    }

    private func refresh() {
        if let state = word.selectionState() { update(with: state) } else { hide() }
    }

    // MARK: - Acciones con estado

    private var currentHighlight: HighlightColor? {
        WordBridge.highlightColors.first { $0.term == Settings.highlightTerm }
    }

    private func applyFontColor(_ color: NSColor?) {
        Settings.fontColor = color
        colorButton.image = Icons.fontColor(color)
        word.setFontColor(color)
    }

    private func applyHighlight(_ color: HighlightColor?) {
        Settings.highlightTerm = color?.term ?? ""
        highlightButton.image = Icons.highlighter(color?.color)
        word.setHighlight(color)
    }

    private func togglePainter(_ event: NSEvent) {
        if event.clickCount >= 2 {
            // Doble clic: queda activo hasta pulsar Esc o volver a hacer clic.
            painterArmed = true
            painterSticky = true
        } else if painterArmed {
            painterArmed = false
            painterSticky = false
        } else {
            word.copyFormat()
            painterArmed = true
            painterSticky = false
        }
    }

    private func newComment() {
        hide()
        if Keyboard.isTrusted {
            Keyboard.newComment()
        } else {
            word.addEmptyComment()
        }
    }

    // MARK: - Menús

    private func item(_ title: String, checked: Bool = false, image: NSImage? = nil,
                      _ action: @escaping () -> Void) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, action: action)
        item.state = checked ? .on : .off
        item.image = image
        return item
    }

    private func makeFontMenu() -> NSMenu {
        let current = state?.fontName ?? ""
        let menu = NSMenu()
        let recents = Settings.recentFonts
        if !recents.isEmpty {
            menu.addItem(.sectionHeader(title: "Fuentes usadas recientemente"))
            for name in recents { menu.addItem(fontItem(name, current: current)) }
            menu.addItem(.separator())
        }
        menu.addItem(.sectionHeader(title: "Todas las fuentes"))
        if fontMenu == nil {
            let all = NSMenu()
            for family in NSFontManager.shared.availableFontFamilies where !family.hasPrefix(".") {
                all.addItem(fontItem(family, current: ""))
            }
            fontMenu = all
        }
        for item in fontMenu!.items {
            let copy = item.copy() as! NSMenuItem
            copy.state = copy.title == current ? .on : .off
            menu.addItem(copy)
        }
        return menu
    }

    private func fontItem(_ name: String, current: String) -> NSMenuItem {
        let item = self.item(name, checked: name == current) { [unowned self] in
            Settings.noteRecentFont(name)
            perform { word.setFontName(name) }
        }
        if let font = NSFont(name: name, size: 13) ?? NSFontManager.shared.font(withFamily: name, traits: [], weight: 5, size: 13) {
            item.attributedTitle = NSAttributedString(string: name, attributes: [.font: font])
        }
        return item
    }

    private func makeSizeMenu() -> NSMenu {
        let menu = NSMenu()
        for size in Self.sizes {
            menu.addItem(item(Self.formatSize(size), checked: state?.fontSize == size) { [unowned self] in
                perform { word.setFontSize(size) }
            })
        }
        menu.addItem(.separator())
        menu.addItem(item("Aumentar tamaño") { [unowned self] in stepSize(+1) })
        menu.addItem(item("Reducir tamaño") { [unowned self] in stepSize(-1) })
        return menu
    }

    private func stepSize(_ direction: Int) {
        let current = state?.fontSize ?? 11
        let next = direction > 0 ? Self.sizes.first { $0 > current } ?? current + 10
                                 : Self.sizes.last { $0 < current } ?? max(1, current - 1)
        perform { word.setFontSize(next) }
    }

    private func makeFontColorMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item("Automático", image: Icons.swatch(.labelColor)) { [unowned self] in applyFontColor(nil) })
        menu.addItem(.separator())

        let theme = Self.themeColors()
        let standard = [0xC00000, 0xFF0000, 0xFFC000, 0xFFFF00, 0x92D050, 0x00B050, 0x00B0F0, 0x0070C0, 0x002060, 0x7030A0]
            .map { SwatchGrid.Swatch(color: .hex($0), name: String(format: "#%06X", $0)) }
        let grid = SwatchGrid(rows: theme + [standard],
                              titles: ["Colores del tema", nil, nil, nil, nil, nil, "Colores estándar"]) { [unowned self] s in
            applyFontColor(s.color)
        }
        let gridItem = NSMenuItem()
        gridItem.view = grid
        menu.addItem(gridItem)
        menu.addItem(.separator())
        menu.addItem(item("Más colores…", image: Icons.symbol("paintpalette", size: 13)) { [unowned self] in openColorPanel() })
        return menu
    }

    /// Paleta del tema de Office: colores base y sus variantes más claras/oscuras.
    private static func themeColors() -> [[SwatchGrid.Swatch]] {
        let base = [0xFFFFFF, 0x000000, 0xE7E6E6, 0x44546A, 0x4472C4, 0xED7D31, 0xA5A5A5, 0xFFC000, 0x5B9BD5, 0x70AD47]
        // Por columna: (aclarar > 0 | oscurecer < 0) para las cinco filas de variantes.
        func variants(_ i: Int) -> [Double] {
            switch i {
            case 0: return [-0.05, -0.15, -0.25, -0.35, -0.5]
            case 1: return [0.5, 0.35, 0.25, 0.15, 0.05]
            case 2: return [-0.1, -0.25, -0.5, -0.75, -0.9]
            default: return [0.8, 0.6, 0.4, -0.25, -0.5]
            }
        }
        func adjust(_ hex: Int, _ t: Double) -> NSColor {
            let c = NSColor.hex(hex)
            func f(_ v: CGFloat) -> CGFloat { t > 0 ? v + (1 - v) * t : v * (1 + t) }
            return NSColor(srgbRed: f(c.redComponent), green: f(c.greenComponent), blue: f(c.blueComponent), alpha: 1)
        }
        var rows = [base.map { SwatchGrid.Swatch(color: .hex($0), name: String(format: "#%06X", $0)) }]
        for r in 0..<5 {
            rows.append(base.indices.map { i in
                let t = variants(i)[r]
                let label = t > 0 ? "Más claro \(Int(t * 100)) %" : "Más oscuro \(Int(-t * 100)) %"
                return SwatchGrid.Swatch(color: adjust(base[i], t), name: label)
            })
        }
        return rows
    }

    private func openColorPanel() {
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged(_:)))
        panel.color = Settings.fontColor ?? .black
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorPanelChanged(_ sender: NSColorPanel) {
        applyFontColor(sender.color)
    }

    @objc private func colorPanelClosed(_ note: Notification) {
        word.wordApp?.activate()
    }

    private func makeHighlightMenu() -> NSMenu {
        let menu = NSMenu()
        let colors = WordBridge.highlightColors
        let rows = stride(from: 0, to: colors.count, by: 5).map { start in
            colors[start..<min(start + 5, colors.count)].map { SwatchGrid.Swatch(color: $0.color, name: $0.label) }
        }
        let grid = SwatchGrid(rows: rows, titles: []) { [unowned self] s in
            applyHighlight(colors.first { $0.label == s.name })
        }
        let gridItem = NSMenuItem()
        gridItem.view = grid
        menu.addItem(gridItem)
        menu.addItem(.separator())
        menu.addItem(item("Sin color", image: Icons.swatch(nil)) { [unowned self] in applyHighlight(nil) })
        return menu
    }

    private func makeListMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item("Viñetas", image: Icons.symbol("list.bullet", size: 13)) { [unowned self] in
            perform { word.toggleBullets() }
        })
        menu.addItem(item("Numeración", image: Icons.symbol("list.number", size: 13)) { [unowned self] in
            perform { word.toggleNumbering() }
        })
        menu.addItem(.separator())
        menu.addItem(item("Quitar lista") { [unowned self] in perform { word.removeList() } })
        return menu
    }

    private func makeStyleMenu() -> NSMenu {
        let menu = NSMenu()
        let names = word.loadStyleNames()
        let current = state?.styleName ?? ""
        for (style, name) in zip(WordBridge.styles, names) {
            let item = self.item(name, checked: name == current) { [unowned self] in
                perform { word.applyStyle(style) }
            }
            item.attributedTitle = Self.stylePreview(name, term: style.term)
            menu.addItem(item)
        }
        return menu
    }

    /// Vista previa aproximada de cada estilo en el menú.
    private static func stylePreview(_ name: String, term: String) -> NSAttributedString {
        var font = NSFont.systemFont(ofSize: 13)
        var color = NSColor.labelColor
        switch term {
        case "style title": font = .systemFont(ofSize: 20, weight: .light)
        case "style subtitle": font = .systemFont(ofSize: 14); color = .secondaryLabelColor
        case "style heading1": font = .systemFont(ofSize: 17, weight: .regular); color = .hex(0x2F5496)
        case "style heading2": font = .systemFont(ofSize: 15, weight: .regular); color = .hex(0x2F5496)
        case "style heading3", "style heading4": font = .systemFont(ofSize: 13.5, weight: .medium); color = .hex(0x1F3763)
        case "style quote", "style emphasis", "style subtle emphasis":
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            if term != "style emphasis" { color = .secondaryLabelColor }
        case "style intense quote", "style intense emphasis":
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask); color = .hex(0x4472C4)
        case "style strong": font = .systemFont(ofSize: 13, weight: .bold)
        case "style caption": font = NSFontManager.shared.convert(.systemFont(ofSize: 11), toHaveTrait: .italicFontMask); color = .hex(0x44546A)
        default: break
        }
        return NSAttributedString(string: name, attributes: [.font: font, .foregroundColor: color])
    }
}

/// NSMenuItem que ejecuta un closure.
final class ClosureMenuItem: NSMenuItem {
    private var handler: (() -> Void)?

    convenience init(title: String, action: @escaping () -> Void) {
        self.init(title: title, action: #selector(fire), keyEquivalent: "")
        handler = action
        target = self
    }

    @objc private func fire() { handler?() }

    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone) as! ClosureMenuItem
        copy.handler = handler
        copy.target = copy
        return copy
    }
}

extension Toolbar {
    /// Imagen de la barra con un estado de ejemplo (`MiniBarra --preview archivo.png`).
    func snapshot(dark: Bool) -> Data? {
        update(with: SelectionState(fontName: "Arial", fontSize: 9, bold: true, italic: false,
                                    underline: false, styleName: "Normal"))
        guard let view = panel.contentView else { return nil }
        view.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        view.layoutSubtreeIfNeeded()
        var data: Data?
        view.appearance?.performAsCurrentDrawingAppearance {
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            data = rep.representation(using: .png, properties: [:])
        }
        return data
    }
}
