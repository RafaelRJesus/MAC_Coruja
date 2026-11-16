import AppKit

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

    /// Área clicável da orelha direita (tufo do lado direito da tela + o brinco).
    static func rightEarArea(in r: NSRect) -> NSRect {
        let g = Geo(r)
        return g.R(0.56, 0.76, 0.28, 0.19).union(g.R(0.75, 0.70, 0.11, 0.14))
    }

    /// Brinco na orelha direita: argolinha dourada com uma pedra redonda pendurada.
    /// A cor da pedra identifica a configuração ativa.
    static func drawEarring(_ g: Geo, gem: NSColor) {
        let gold = NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.25, alpha: 1)

        // argola presa na ponta do tufo
        let ring = oval(NSRect(x: g.P(0.765, 0.785).x, y: g.P(0.765, 0.785).y,
                               width: 0.045 * g.s, height: 0.045 * g.s))
        ring.lineWidth = 0.012 * g.s
        gold.setStroke()
        ring.stroke()

        // pedra redonda com aro dourado e brilho
        let ball = g.R(0.762, 0.715, 0.06, 0.06)
        gold.setFill()
        oval(ball.insetBy(dx: -0.008 * g.s, dy: -0.008 * g.s)).fill()
        gem.setFill()
        oval(ball).fill()
        NSColor.white.withAlphaComponent(0.8).setFill()
        oval(NSRect(x: ball.minX + ball.width * 0.22, y: ball.minY + ball.height * 0.55,
                    width: ball.width * 0.28, height: ball.height * 0.28)).fill()
    }

    static func oval(_ r: NSRect) -> NSBezierPath { NSBezierPath(ovalIn: r) }

    static func triangle(_ a: NSPoint, _ b: NSPoint, _ c: NSPoint) -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: a); p.line(to: b); p.line(to: c); p.close()
        return p
    }

    static func draw(in r: NSRect, eyesOpen: Bool, gem: NSColor = NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.10, alpha: 1)) {
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

        // brinco (por último, para ficar por cima do tufo)
        drawEarring(g, gem: gem)
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
