// Coruja — um amiguinho de mesa que mantém o Mac acordado.
// Olhos abertos: a tela não descansa e você segue ativo.
// Olhos fechados: tudo volta ao normal e o Mac pode descansar/hibernar.
// Orelha direita (brinco): quando dormir. Orelha esquerda: animações. Barriga: carinho.

import AppKit

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: OwlWindow!
    let animator = OwlAnimator()
    lazy var owl = OwlView(animator: animator, owlSize: Settings.size.points)
    let keeper = KeepAwake()
    var tickTimer: Timer?
    var deadline: Date?
    let toggleItem = NSMenuItem(title: "Acordar a coruja", action: #selector(toggle), keyEquivalent: "")
    let onTopItem = NSMenuItem(title: "Sempre na frente", action: #selector(toggleOnTop), keyEquivalent: "")

    // Laço de animação (taxa de quadros se adapta ao que está acontecendo)
    private var frameTimer: Timer?
    private var currentFPS: Double = 0
    private var lastFrame: TimeInterval = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()

        window = OwlWindow(contentRect: owl.frame, styleMask: [.borderless],
                           backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces]
        window.contentView = owl
        if let f = NSScreen.main?.visibleFrame {
            window.setFrameOrigin(NSPoint(x: f.maxX - owl.frame.width - 30, y: f.minY + 10))
        }
        window.setFrameAutosaveName("CorujaJanela")
        window.makeKeyAndOrderFront(nil)

        owl.gem = Settings.mode.gemColor
        owl.onToggle = { [weak self] in self?.toggle() }
        owl.onRightEar = { [weak self] rect in self?.showSettings(from: rect) }
        owl.onLeftEar = { [weak self] rect in self?.showAnimations(from: rect) }
        owl.onDragChanged = { [weak self] dragging in
            guard let self = self else { return }
            self.animator.dragging = dragging
            if Settings.animationsOn { self.setFPS(self.animator.desiredFPS) }
        }

        animator.canWalk = { [weak self] in
            guard let self = self else { return false }
            return !self.popover.isShown && !self.animationPopover.isShown
        }
        animator.moveWindow = { [weak self] dx in self?.moveWindow(by: dx) ?? false }

        owl.menu = makeMenu()
        updateStatus()

        // Quando a coruja está escondida (atrás de janelas, outra mesa, tela apagada), pausa tudo
        NotificationCenter.default.addObserver(self, selector: #selector(occlusionChanged),
                                               name: NSWindow.didChangeOcclusionStateNotification,
                                               object: window)

        animator.staticFrame()
        startAnimating()

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

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        toggleItem.target = self
        onTopItem.target = self
        onTopItem.state = .on
        let settingsItem = NSMenuItem(title: "Quando dormir…", action: #selector(openSettingsFromMenu), keyEquivalent: "")
        settingsItem.target = self
        let animItem = NSMenuItem(title: "Animações…", action: #selector(openAnimationsFromMenu), keyEquivalent: "")
        animItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(settingsItem)
        menu.addItem(animItem)
        menu.addItem(onTopItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Sair", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        return menu
    }

    // MARK: Animação

    /// Liga o laço de quadros (se as animações estiverem ligadas e a coruja visível).
    func startAnimating() {
        guard Settings.animationsOn else {
            stopAnimating()
            return
        }
        guard window.occlusionState.contains(.visible) else { return }
        setFPS(animator.desiredFPS)
    }

    /// Desliga tudo: coruja parada, sem nenhum timer de animação.
    func stopAnimating() {
        pauseAnimating()
        animator.staticFrame()
        owl.needsDisplay = true
    }

    private func pauseAnimating() {
        frameTimer?.invalidate()
        frameTimer = nil
        currentFPS = 0
    }

    func setFPS(_ fps: Double) {
        guard fps != currentFPS || frameTimer == nil else { return }
        frameTimer?.invalidate()
        currentFPS = fps
        let t = Timer(timeInterval: 1 / fps, repeats: true) { [weak self] _ in self?.frame() }
        t.tolerance = 0.25 / fps          // deixa o sistema agrupar os disparos (economiza energia)
        RunLoop.main.add(t, forMode: .common)
        frameTimer = t
        lastFrame = ProcessInfo.processInfo.systemUptime
    }

    private func frame() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastFrame)
        lastFrame = now

        // olhar para o mouse
        if let eye = owl.eyesCenterOnScreen {
            let m = NSEvent.mouseLocation
            let dx = m.x - eye.x, dy = m.y - eye.y
            let d = max(1, hypot(dx, dy))
            let k = min(1, d / 200)
            animator.mouseLook = CGPoint(x: dx / d * k, y: dy / d * k)
        }

        animator.update(dt)
        owl.needsDisplay = true

        let want = animator.desiredFPS
        if want != currentFPS { setFPS(want) }
    }

    @objc private func occlusionChanged() {
        if window.occlusionState.contains(.visible) {
            startAnimating()
        } else {
            pauseAnimating()
        }
    }

    /// Passeio: move a janela de lado, sem sair da tela.
    private func moveWindow(by dx: CGFloat) -> Bool {
        guard let screen = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return false }
        var o = window.frame.origin
        let wanted = o.x + dx
        let x = min(max(wanted, screen.minX), screen.maxX - window.frame.width)
        o.x = x
        window.setFrameOrigin(o)
        return x == wanted
    }

    func applyAnimationSettings() {
        Settings.animationsOn ? startAnimating() : stopAnimating()
    }

    func applySize() {
        let s = Settings.size.points
        let size = OwlView.frameSize(for: s)
        var f = window.frame
        f.origin.x = f.midX - size.width / 2
        f.size = size
        window.setFrame(f, display: true)
        owl.owlSize = s
        owl.frame = NSRect(origin: .zero, size: size)
        window.invalidateCursorRects(for: owl)
    }

    func playNow(_ activity: Activity) {
        guard Settings.animationsOn else { return }
        animator.play(activity)
        startAnimating()
    }

    // MARK: Acordar e dormir

    @objc func toggle() {
        keeper.active ? sleepOwl() : wakeOwl()
    }

    /// Abre os olhos e, se houver limite configurado, começa a contar.
    func wakeOwl() {
        if !keeper.active {
            askAccessibilityIfNeeded()
            keeper.start()
            toggleItem.title = "Pôr a coruja para dormir"
            if Settings.animationsOn {
                animator.wake()
                startAnimating()
            } else {
                animator.awake = true
                animator.staticFrame()
                owl.needsDisplay = true
            }
        }
        deadline = Settings.deadline()
        startTick()
    }

    /// Fecha os olhos e devolve o Mac ao comportamento normal.
    func sleepOwl() {
        keeper.stop()
        toggleItem.title = "Acordar a coruja"
        deadline = nil
        tickTimer?.invalidate()
        tickTimer = nil
        updateStatus()
        if Settings.animationsOn {
            animator.sleep()
            startAnimating()
        } else {
            animator.awake = false
            animator.staticFrame()
            owl.needsDisplay = true
        }
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
        tickTimer?.tolerance = 0.3
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

    // MARK: Painéis das orelhas

    lazy var popover: NSPopover = {
        let p = NSPopover()
        p.behavior = .transient
        let vc = SettingsViewController()
        vc.app = self
        p.contentViewController = vc
        return p
    }()

    lazy var animationPopover: NSPopover = {
        let p = NSPopover()
        p.behavior = .transient
        let vc = AnimationPanelController()
        vc.app = self
        p.contentViewController = vc
        return p
    }()

    func showSettings(from rect: NSRect) {
        show(popover, from: rect, closing: animationPopover)
    }

    func showAnimations(from rect: NSRect) {
        show(animationPopover, from: rect, closing: popover)
    }

    private func show(_ p: NSPopover, from rect: NSRect, closing other: NSPopover) {
        if other.isShown { other.performClose(nil) }
        if p.isShown {
            p.performClose(nil)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        p.show(relativeTo: rect, of: owl, preferredEdge: .maxY)
    }

    @objc func openSettingsFromMenu() {
        showSettings(from: owl.rightEarRect)
    }

    @objc func openAnimationsFromMenu() {
        showAnimations(from: owl.leftEarRect)
    }

    @objc func toggleOnTop() {
        let onTop = window.level == .floating
        window.level = onTop ? .normal : .floating
        onTopItem.state = onTop ? .off : .on
    }

    // MARK: Permissão

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
