import AppKit

// MARK: - View da coruja

/// Desenha a coruja e os efeitos a partir do estado do animador e trata os cliques:
/// olhos = acordar/dormir, orelha direita (brinco) = quando dormir,
/// orelha esquerda = animações, barriga = carinho, arrastar = mover.
final class OwlView: NSView {
    let animator: OwlAnimator
    var owlSize: CGFloat { didSet { needsDisplay = true } }
    var gem: NSColor = LimitMode.none.gemColor { didSet { needsDisplay = true } }

    var onToggle: (() -> Void)?
    var onRightEar: ((NSRect) -> Void)?
    var onLeftEar: ((NSRect) -> Void)?
    var onDragChanged: ((Bool) -> Void)?

    private var downPoint = NSPoint.zero
    private var dragStart: NSPoint?
    private var windowStart: NSPoint?
    private var didDrag = false

    /// Tamanho da janela para uma coruja de tamanho `s` (sobra espaço para sol, corações e ninho).
    static func frameSize(for s: CGFloat) -> NSSize {
        NSSize(width: s * 1.5, height: s * 1.45)
    }

    init(animator: OwlAnimator, owlSize: CGFloat) {
        self.animator = animator
        self.owlSize = owlSize
        super.init(frame: NSRect(origin: .zero, size: OwlView.frameSize(for: owlSize)))
    }

    required init?(coder: NSCoder) { fatalError("não usado") }

    /// Quadrado onde a coruja parada fica (centro, perto da base da janela).
    var baseRect: NSRect {
        NSRect(x: (bounds.width - owlSize) / 2, y: owlSize * 0.12, width: owlSize, height: owlSize)
    }

    /// Onde a coruja está agora (com pulinhos e deslocamentos).
    var owlRect: NSRect {
        baseRect.offsetBy(dx: animator.offset.x * owlSize, dy: animator.offset.y * owlSize)
    }

    var rightEarRect: NSRect { Owl.rightEarArea(in: owlRect) }
    var leftEarRect: NSRect { Owl.leftEarArea(in: owlRect) }

    /// Centro dos olhos na tela (para a coruja olhar para o mouse).
    var eyesCenterOnScreen: NSPoint? {
        guard let w = window else { return nil }
        let e = Owl.eyeAreas(in: owlRect)
        let local = NSPoint(x: (e[0].midX + e[1].midX) / 2, y: e[0].midY)
        return w.convertPoint(toScreen: convert(local, to: nil))
    }

    // MARK: Desenho

    override func draw(_ dirtyRect: NSRect) {
        let a = animator
        let base = Geo(baseRect)

        // sol fica atrás da coruja
        if let sun = a.sun {
            Effects.withAlpha(sun.alpha) {
                Effects.drawSun(g: base, progress: sun.pos, spin: a.sunSpin)
            }
        }

        // coruja com inclinação e "respiração", ancorada nos pés
        let r = owlRect
        NSGraphicsContext.saveGraphicsState()
        let anchor = NSPoint(x: r.midX, y: r.minY + owlSize * 0.05)
        let xf = NSAffineTransform()
        xf.translateX(by: anchor.x, yBy: anchor.y)
        xf.rotate(byDegrees: -a.tilt)
        xf.scaleX(by: 1 - (a.squash - 1) * 0.5, yBy: a.squash)
        xf.translateX(by: -anchor.x, yBy: -anchor.y)
        xf.concat()
        Owl.draw(in: r, pose: a.pose, gem: gem)
        if let prop = a.prop, prop == .partyHat {
            Effects.drawProp(prop, g: Geo(r), phase: a.propPhase)
        }
        NSGraphicsContext.restoreGraphicsState()

        // objetos na frente (caneca, tigela, biscoito acompanham a coruja)
        if let prop = a.prop, prop != .partyHat {
            Effects.drawProp(prop, g: prop == .bowl ? base : Geo(r), phase: a.propPhase)
        }

        // ninho na frente da coruja
        if a.nest > 0.01 {
            Effects.drawNest(g: base, amount: a.nest)
        }

        // partículas por cima de tudo
        for p in a.particles {
            Effects.draw(p, g: base)
        }
    }

    // MARK: Mouse

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        downPoint = convert(event.locationInWindow, from: nil)
        dragStart = NSEvent.mouseLocation
        windowStart = window?.frame.origin
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, let origin = windowStart else { return }
        let m = NSEvent.mouseLocation
        let dx = m.x - start.x, dy = m.y - start.y
        if !didDrag && hypot(dx, dy) < 3 { return }
        if !didDrag {
            didDrag = true
            onDragChanged?(true)
        }
        window?.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
        if didDrag {
            didDrag = false
            onDragChanged?(false)
            return
        }
        let p = downPoint
        let r = owlRect
        if rightEarRect.contains(p) {
            onRightEar?(rightEarRect)
        } else if leftEarRect.contains(p) {
            onLeftEar?(leftEarRect)
        } else if Owl.eyeAreas(in: r).contains(where: { $0.contains(p) }) {
            onToggle?()
        } else if Owl.bellyArea(in: r).contains(p) {
            animator.pet()
        }
    }

    override func resetCursorRects() {
        let r = baseRect
        for e in Owl.eyeAreas(in: r) { addCursorRect(e, cursor: .pointingHand) }
        addCursorRect(Owl.rightEarArea(in: r), cursor: .pointingHand)
        addCursorRect(Owl.leftEarArea(in: r), cursor: .pointingHand)
    }
}

final class OwlWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
