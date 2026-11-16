// Coruja — um app de mesa com uma coruja.
// Olhos abertos: a coruja fica acordada (o Mac não descansa a tela e você segue ativo).
// Olhos fechados: tudo volta ao normal e o Mac pode descansar/hibernar.
// Clique nos olhos para alternar. Botão direito na coruja abre o menu.

import AppKit

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: OwlWindow!
    let owl = OwlView(frame: NSRect(x: 0, y: 0, width: 160, height: 160))
    let keeper = KeepAwake()
    var blinkTimer: Timer?
    var tickTimer: Timer?
    var deadline: Date?
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

        owl.gem = Settings.mode.gemColor
        owl.onToggle = { [weak self] in self?.toggle() }
        owl.onRightEar = { [weak self] rect in self?.showSettings(from: rect) }

        let menu = NSMenu()
        toggleItem.target = self
        onTopItem.target = self
        onTopItem.state = .on
        let settingsItem = NSMenuItem(title: "Configurações…", action: #selector(openSettingsFromMenu), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(settingsItem)
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
        keeper.active ? sleepOwl() : wakeOwl()
    }

    /// Abre os olhos e, se houver limite configurado, começa a contar.
    func wakeOwl() {
        if !keeper.active {
            askAccessibilityIfNeeded()
            keeper.start()
            owl.eyesOpen = true
            toggleItem.title = "Pôr a coruja para dormir"
            scheduleBlink()
        }
        deadline = Settings.deadline()
        startTick()
    }

    /// Fecha os olhos e devolve o Mac ao comportamento normal.
    func sleepOwl() {
        keeper.stop()
        owl.eyesOpen = false
        blinkTimer?.invalidate()
        toggleItem.title = "Acordar a coruja"
        deadline = nil
        tickTimer?.invalidate()
        tickTimer = nil
        updateStatus()
    }

    // Relógio de 1 em 1 segundo: confere o limite e atualiza o texto de status
    func startTick() {
        tickTimer?.invalidate()
        tickTimer = nil
        updateStatus()
        guard deadline != nil else { return }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, let d = self.deadline else { return }
            if Date() >= d {
                self.sleepOwl()
            } else {
                self.updateStatus()
            }
        }
    }

    /// Texto que descreve o estado atual (usado na dica do mouse e no painel).
    var statusText: String {
        guard keeper.active else { return "Dormindo" }
        guard let d = deadline else { return "Acordada, sem limite" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "Dorme em \(formatRemaining(d.timeIntervalSinceNow)) (às \(f.string(from: d)))"
    }

    func updateStatus() {
        owl.toolTip = statusText
    }

    lazy var popover: NSPopover = {
        let p = NSPopover()
        p.behavior = .transient
        let vc = SettingsViewController()
        vc.app = self
        p.contentViewController = vc
        return p
    }()

    func showSettings(from rect: NSRect) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: rect, of: owl, preferredEdge: .maxY)
    }

    @objc func openSettingsFromMenu() {
        showSettings(from: owl.rightEarRect)
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

    private var askedAccessibility = false

    /// Pede a permissão só se ainda não tiver e no máximo uma vez por abertura do app.
    func askAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted(), !askedAccessibility else { return }
        askedAccessibility = true
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
