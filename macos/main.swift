// Coruja — um app de mesa com uma coruja.
// Olhos abertos: a coruja fica acordada (o Mac não descansa a tela e você segue ativo).
// Olhos fechados: tudo volta ao normal e o Mac pode descansar/hibernar.
// Clique nos olhos para alternar. Botão direito na coruja abre o menu.

import AppKit
import IOKit.pwr_mgt

// MARK: - Geometria (tudo proporcional ao tamanho da coruja)

struct Geo {
    let s: CGFloat
    let o: NSPoint
    init(_ r: NSRect) {
        s = min(r.width, r.height)
        o = NSPoint(x: r.midX - s / 2, y: r.midY - s / 2)
    }
    func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: o.x + x * s, y: o.y + y * s, width: w * s, height: h * s)
    }
    func P(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: o.x + x * s, y: o.y + y * s)
    }
}

// MARK: - Desenho da coruja

enum Owl {
    static let body  = NSColor(calibratedRed: 0.48, green: 0.33, blue: 0.22, alpha: 1)
    static let dark  = NSColor(calibratedRed: 0.33, green: 0.21, blue: 0.13, alpha: 1)
    static let belly = NSColor(calibratedRed: 0.88, green: 0.76, blue: 0.58, alpha: 1)
    static let mask  = NSColor(calibratedRed: 0.93, green: 0.85, blue: 0.70, alpha: 1)
    static let beak  = NSColor(calibratedRed: 0.96, green: 0.64, blue: 0.16, alpha: 1)
    static let iris  = NSColor(calibratedRed: 0.99, green: 0.76, blue: 0.10, alpha: 1)

    static func eyeAreas(in r: NSRect) -> [NSRect] {
        let g = Geo(r)
        return [g.R(0.21, 0.45, 0.30, 0.30), g.R(0.49, 0.45, 0.30, 0.30)]
    }

    static func oval(_ r: NSRect) -> NSBezierPath { NSBezierPath(ovalIn: r) }

    static func triangle(_ a: NSPoint, _ b: NSPoint, _ c: NSPoint) -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: a); p.line(to: b); p.line(to: c); p.close()
        return p
    }

    static func draw(in r: NSRect, eyesOpen: Bool) {
        let g = Geo(r)

        // tufos das orelhas
        dark.setFill()
        triangle(g.P(0.24, 0.68), g.P(0.19, 0.93), g.P(0.42, 0.80)).fill()
        triangle(g.P(0.76, 0.68), g.P(0.81, 0.93), g.P(0.58, 0.80)).fill()

        // asas
        oval(g.R(0.12, 0.18, 0.20, 0.42)).fill()
        oval(g.R(0.68, 0.18, 0.20, 0.42)).fill()

        // corpo e barriga
        body.setFill()
        oval(g.R(0.18, 0.07, 0.64, 0.80)).fill()
        belly.setFill()
        oval(g.R(0.30, 0.09, 0.40, 0.42)).fill()

        // penas da barriga
        let feather = NSBezierPath()
        feather.lineWidth = 0.012 * g.s
        feather.lineCapStyle = .round
        feather.lineJoinStyle = .round
        let marks: [(CGFloat, CGFloat)] = [(0.42, 0.33), (0.58, 0.33), (0.50, 0.25), (0.42, 0.17), (0.58, 0.17)]
        for (x, y) in marks {
            feather.move(to: g.P(x - 0.03, y + 0.02))
            feather.line(to: g.P(x, y))
            feather.line(to: g.P(x + 0.03, y + 0.02))
        }
        dark.withAlphaComponent(0.45).setStroke()
        feather.stroke()

        // pés
        beak.setFill()
        oval(g.R(0.36, 0.045, 0.11, 0.05)).fill()
        oval(g.R(0.53, 0.045, 0.11, 0.05)).fill()

        // olhos
        let eyes = eyeAreas(in: r)
        mask.setFill()
        for e in eyes { oval(e).fill() }

        for e in eyes {
            let inner = e.insetBy(dx: 0.03 * g.s, dy: 0.03 * g.s)
            if eyesOpen {
                NSColor.white.setFill(); oval(inner).fill()
                let ir = inner.insetBy(dx: inner.width * 0.18, dy: inner.height * 0.18)
                iris.setFill(); oval(ir).fill()
                let pupil = ir.insetBy(dx: ir.width * 0.25, dy: ir.height * 0.25)
                NSColor.black.setFill(); oval(pupil).fill()
                let hl = NSRect(x: pupil.midX, y: pupil.midY,
                                width: pupil.width * 0.35, height: pupil.height * 0.35)
                NSColor.white.setFill(); oval(hl).fill()
            } else {
                body.setFill(); oval(inner).fill()
                let lid = NSBezierPath()
                lid.lineWidth = 0.02 * g.s
                lid.lineCapStyle = .round
                let y = inner.midY
                lid.move(to: NSPoint(x: inner.minX + inner.width * 0.12, y: y))
                lid.curve(to: NSPoint(x: inner.maxX - inner.width * 0.12, y: y),
                          controlPoint1: NSPoint(x: inner.minX + inner.width * 0.30, y: y - inner.height * 0.30),
                          controlPoint2: NSPoint(x: inner.maxX - inner.width * 0.30, y: y - inner.height * 0.30))
                dark.setStroke(); lid.stroke()
            }
        }

        // bico
        beak.setFill()
        triangle(g.P(0.46, 0.47), g.P(0.54, 0.47), g.P(0.50, 0.37)).fill()
    }

    /// Ícone do app (fundo noturno arredondado + coruja de olhos abertos).
    static func iconPNG(size: Int) -> Data? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                         isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let s = CGFloat(size)
        let bg = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
        let bgPath = NSBezierPath(roundedRect: bg, xRadius: s * 0.18, yRadius: s * 0.18)
        let gradient = NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.38, alpha: 1),
                                  ending: NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.20, alpha: 1))
        gradient?.draw(in: bgPath, angle: -90)
        draw(in: bg.insetBy(dx: s * 0.06, dy: s * 0.06), eyesOpen: true)
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}

// MARK: - Mantém o Mac acordado

final class KeepAwake {
    private var assertionID: IOPMAssertionID = 0
    private var timer: Timer?
    private(set) var active = false

    func start() {
        guard !active else { return }
        active = true
        IOPMAssertionCreateWithName("PreventUserIdleDisplaySleep" as CFString,
                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                    "Coruja acordada" as CFString,
                                    &assertionID)
        ping()
        // A cada 4 minutos (o Teams marca "Ausente" após ~5 min sem atividade)
        timer = Timer.scheduledTimer(withTimeInterval: 240, repeats: true) { [weak self] _ in
            self?.ping()
        }
    }

    func stop() {
        guard active else { return }
        active = false
        timer?.invalidate()
        timer = nil
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
    }

    private func ping() {
        var uid: IOPMAssertionID = 0
        IOPMAssertionDeclareUserActivity("Coruja" as CFString, kIOPMUserActiveLocal, &uid)
        // Tecla F15 (não existe no teclado e não faz nada) para zerar o tempo ocioso
        let src = CGEventSource(stateID: .hidSystemState)
        CGEvent(keyboardEventSource: src, virtualKey: 113, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: src, virtualKey: 113, keyDown: false)?.post(tap: .cghidEventTap)
    }
}

// MARK: - View da coruja

final class OwlView: NSView {
    var eyesOpen = false { didSet { needsDisplay = true } }
    var blinking = false { didSet { needsDisplay = true } }
    var onToggle: (() -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        Owl.draw(in: bounds, eyesOpen: eyesOpen && !blinking)
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if Owl.eyeAreas(in: bounds).contains(where: { $0.contains(p) }) {
            onToggle?()
        } else {
            window?.performDrag(with: event)   // arrastar a coruja pela tela
        }
    }

    override func resetCursorRects() {
        for e in Owl.eyeAreas(in: bounds) { addCursorRect(e, cursor: .pointingHand) }
    }
}

final class OwlWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: OwlWindow!
    let owl = OwlView(frame: NSRect(x: 0, y: 0, width: 160, height: 160))
    let keeper = KeepAwake()
    var blinkTimer: Timer?
    let toggleItem = NSMenuItem(title: "Acordar a coruja", action: #selector(toggle), keyEquivalent: "")
    let onTopItem = NSMenuItem(title: "Sempre na frente", action: #selector(toggleOnTop), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()

        window = OwlWindow(contentRect: owl.frame, styleMask: [.borderless],
                           backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces]
        window.contentView = owl
        if let f = NSScreen.main?.visibleFrame {
            window.setFrameOrigin(NSPoint(x: f.maxX - 190, y: f.minY + 30))
        }
        window.setFrameAutosaveName("CorujaJanela")
        window.makeKeyAndOrderFront(nil)

        owl.onToggle = { [weak self] in self?.toggle() }

        let menu = NSMenu()
        toggleItem.target = self
        onTopItem.target = self
        onTopItem.state = .on
        menu.addItem(toggleItem)
        menu.addItem(onTopItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Sair", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        owl.menu = menu

        if let data = Owl.iconPNG(size: 512), let img = NSImage(data: data) {
            NSApp.applicationIconImage = img
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func setupMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Sair da Coruja", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        NSApp.mainMenu = main
    }

    @objc func toggle() {
        if keeper.active {
            keeper.stop()
            owl.eyesOpen = false
            blinkTimer?.invalidate()
            toggleItem.title = "Acordar a coruja"
        } else {
            askAccessibilityIfNeeded()
            keeper.start()
            owl.eyesOpen = true
            toggleItem.title = "Pôr a coruja para dormir"
            scheduleBlink()
        }
    }

    @objc func toggleOnTop() {
        let onTop = window.level == .floating
        window.level = onTop ? .normal : .floating
        onTopItem.state = onTop ? .off : .on
    }

    // Piscadinha de vez em quando enquanto está acordada
    func scheduleBlink() {
        blinkTimer?.invalidate()
        guard keeper.active else { return }
        blinkTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 3...7), repeats: false) { [weak self] _ in
            guard let self = self, self.keeper.active else { return }
            self.owl.blinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.owl.blinking = false
                self.scheduleBlink()
            }
        }
    }

    func askAccessibilityIfNeeded() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    func applicationWillTerminate(_ notification: Notification) {
        keeper.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

// MARK: - Início

let args = CommandLine.arguments
if args.count >= 3, args[1] == "--export-icon" {
    if let data = Owl.iconPNG(size: 1024) {
        try? data.write(to: URL(fileURLWithPath: args[2]))
        exit(0)
    }
    exit(1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
