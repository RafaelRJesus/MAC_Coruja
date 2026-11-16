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

/// Rotação (em graus, sentido anti-horário) em volta de um ponto.
func rotation(_ degrees: CGFloat, around p: NSPoint) -> AffineTransform {
    let a = degrees * .pi / 180
    let c = cos(a), s = sin(a)
    return AffineTransform(m11: c, m12: s, m21: -s, m22: c,
                           tX: p.x - (c * p.x - s * p.y),
                           tY: p.y - (s * p.x + c * p.y))
}

// MARK: - Pose (o "rosto" e o corpo em cada quadro da animação)

struct Pose {
    var lid: CGFloat = 0          // pálpebra: 0 = olho aberto, 1 = fechado
    var look = CGPoint.zero       // direção do olhar (-1...1 em x e y)
    var puppy: CGFloat = 0        // 0...1 carinha de filhote (olhos maiores e brilhantes)
    var happy = false             // olhinhos fechados de alegria (^^)
    var wing: CGFloat = 0         // 0...1 asas levantadas
    var step: CGFloat = 0         // -1...1 passinho (levanta um pé)
    var beakOpen: CGFloat = 0     // 0...1 bico aberto (piar, bocejar, comer)

    static let awake = Pose()
    static let asleep = Pose(lid: 1)
}

// MARK: - Desenho da coruja

enum Owl {
    static let body  = NSColor(calibratedRed: 0.48, green: 0.33, blue: 0.22, alpha: 1)
    static let dark  = NSColor(calibratedRed: 0.33, green: 0.21, blue: 0.13, alpha: 1)
    static let belly = NSColor(calibratedRed: 0.88, green: 0.76, blue: 0.58, alpha: 1)
    static let mask  = NSColor(calibratedRed: 0.93, green: 0.85, blue: 0.70, alpha: 1)
    static let beak  = NSColor(calibratedRed: 0.96, green: 0.64, blue: 0.16, alpha: 1)
    static let iris  = NSColor(calibratedRed: 0.99, green: 0.76, blue: 0.10, alpha: 1)
    static let defaultGem = NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.10, alpha: 1)

    // MARK: Áreas clicáveis

    static func eyeAreas(in r: NSRect) -> [NSRect] {
        let g = Geo(r)
        return [g.R(0.21, 0.45, 0.30, 0.30), g.R(0.49, 0.45, 0.30, 0.30)]
    }

    /// Orelha direita (com brinco): configurações de quando dormir.
    static func rightEarArea(in r: NSRect) -> NSRect {
        let g = Geo(r)
        return g.R(0.56, 0.76, 0.28, 0.19).union(g.R(0.75, 0.70, 0.11, 0.14))
    }

    /// Orelha esquerda (sem brinco): configurações das animações.
    static func leftEarArea(in r: NSRect) -> NSRect {
        Geo(r).R(0.16, 0.76, 0.28, 0.19)
    }

    /// Barriga: fazer carinho.
    static func bellyArea(in r: NSRect) -> NSRect {
        Geo(r).R(0.32, 0.10, 0.36, 0.30)
    }

    // MARK: Formas

    static func oval(_ r: NSRect) -> NSBezierPath { NSBezierPath(ovalIn: r) }

    static func triangle(_ a: NSPoint, _ b: NSPoint, _ c: NSPoint) -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: a); p.line(to: b); p.line(to: c); p.close()
        return p
    }

    // MARK: Coruja completa

    static func draw(in r: NSRect, pose: Pose = .awake, gem: NSColor = defaultGem) {
        let g = Geo(r)

        // tufos das orelhas
        dark.setFill()
        triangle(g.P(0.24, 0.68), g.P(0.19, 0.93), g.P(0.42, 0.80)).fill()
        triangle(g.P(0.76, 0.68), g.P(0.81, 0.93), g.P(0.58, 0.80)).fill()

        // asas (giram para fora quando levantadas)
        drawWing(g, left: true, lift: pose.wing)
        drawWing(g, left: false, lift: pose.wing)

        // corpo e barriga
        body.setFill()
        oval(g.R(0.18, 0.07, 0.64, 0.80)).fill()
        belly.setFill()
        oval(g.R(0.30, 0.09, 0.40, 0.42)).fill()
        drawFeathers(g)

        // pés (um sobe a cada passinho)
        beak.setFill()
        oval(g.R(0.36, 0.045 + max(0, pose.step) * 0.025, 0.11, 0.05)).fill()
        oval(g.R(0.53, 0.045 + max(0, -pose.step) * 0.025, 0.11, 0.05)).fill()

        // olhos
        let eyes = eyeAreas(in: r)
        mask.setFill()
        for e in eyes { oval(e).fill() }
        for e in eyes {
            drawEye(e.insetBy(dx: 0.03 * g.s, dy: 0.03 * g.s), g, pose)
        }

        drawBeak(g, open: pose.beakOpen)
        drawEarring(g, gem: gem)
    }

    static func drawFeathers(_ g: Geo) {
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
    }

    static func drawWing(_ g: Geo, left: Bool, lift: CGFloat) {
        let rect = left ? g.R(0.12, 0.18, 0.20, 0.42) : g.R(0.68, 0.18, 0.20, 0.42)
        let pivot = left ? g.P(0.25, 0.55) : g.P(0.75, 0.55)
        let path = oval(rect)
        if lift > 0.01 {
            path.transform(using: rotation((left ? -1 : 1) * lift * 60, around: pivot))
        }
        dark.setFill()
        path.fill()
    }

    static func drawEye(_ inner: NSRect, _ g: Geo, _ pose: Pose) {
        // olhinhos de alegria: ^^
        if pose.happy {
            body.setFill(); oval(inner).fill()
            let p = NSBezierPath()
            p.lineWidth = 0.022 * g.s
            p.lineCapStyle = .round
            let y = inner.midY - inner.height * 0.08
            p.move(to: NSPoint(x: inner.minX + inner.width * 0.18, y: y))
            p.curve(to: NSPoint(x: inner.maxX - inner.width * 0.18, y: y),
                    controlPoint1: NSPoint(x: inner.minX + inner.width * 0.30, y: y + inner.height * 0.38),
                    controlPoint2: NSPoint(x: inner.maxX - inner.width * 0.30, y: y + inner.height * 0.38))
            dark.setStroke(); p.stroke()
            return
        }

        // olho fechado: curvinha para baixo
        if pose.lid >= 0.97 {
            body.setFill(); oval(inner).fill()
            let p = NSBezierPath()
            p.lineWidth = 0.02 * g.s
            p.lineCapStyle = .round
            let y = inner.midY
            p.move(to: NSPoint(x: inner.minX + inner.width * 0.12, y: y))
            p.curve(to: NSPoint(x: inner.maxX - inner.width * 0.12, y: y),
                    controlPoint1: NSPoint(x: inner.minX + inner.width * 0.30, y: y - inner.height * 0.30),
                    controlPoint2: NSPoint(x: inner.maxX - inner.width * 0.30, y: y - inner.height * 0.30))
            dark.setStroke(); p.stroke()
            return
        }

        // olho aberto (íris e pupila maiores na carinha de filhote)
        NSColor.white.setFill(); oval(inner).fill()
        let irisInset = 0.18 - pose.puppy * 0.07
        var ir = inner.insetBy(dx: inner.width * irisInset, dy: inner.height * irisInset)
        let shift = inner.width * 0.11
        ir = ir.offsetBy(dx: pose.look.x * shift, dy: pose.look.y * shift)
        iris.setFill(); oval(ir).fill()

        let pupilInset = 0.25 - pose.puppy * 0.13
        let pupil = ir.insetBy(dx: ir.width * pupilInset, dy: ir.height * pupilInset)
        NSColor.black.setFill(); oval(pupil).fill()

        NSColor.white.setFill()
        let hs = pupil.width * (0.35 + pose.puppy * 0.1)
        oval(NSRect(x: pupil.midX, y: pupil.midY, width: hs, height: hs)).fill()
        if pose.puppy > 0.2 {
            // brilho extra de filhote
            NSColor.white.withAlphaComponent(pose.puppy).setFill()
            let hs2 = pupil.width * 0.18
            oval(NSRect(x: pupil.minX + pupil.width * 0.2, y: pupil.minY + pupil.height * 0.22,
                        width: hs2, height: hs2)).fill()
        }

        // pálpebra descendo de cima (sono, preguiça, piscada)
        if pose.lid > 0.01 {
            NSGraphicsContext.saveGraphicsState()
            oval(inner).addClip()
            let h = inner.height * pose.lid
            body.setFill()
            NSBezierPath(rect: NSRect(x: inner.minX, y: inner.maxY - h, width: inner.width, height: h)).fill()
            let edge = NSBezierPath()
            edge.lineWidth = 0.014 * g.s
            edge.move(to: NSPoint(x: inner.minX, y: inner.maxY - h))
            edge.line(to: NSPoint(x: inner.maxX, y: inner.maxY - h))
            dark.setStroke(); edge.stroke()
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    static func drawBeak(_ g: Geo, open: CGFloat) {
        guard open > 0.05 else {
            beak.setFill()
            triangle(g.P(0.46, 0.47), g.P(0.54, 0.47), g.P(0.50, 0.37)).fill()
            return
        }
        let gap = open * 0.05
        dark.setFill()
        oval(g.R(0.465, 0.375 - gap, 0.07, 0.05 + gap)).fill()        // boquinha
        beak.setFill()
        triangle(g.P(0.46, 0.47), g.P(0.54, 0.47), g.P(0.50, 0.40)).fill()              // bico de cima
        triangle(g.P(0.475, 0.395 - gap), g.P(0.525, 0.395 - gap), g.P(0.50, 0.36 - gap)).fill() // de baixo
    }

    /// Brinco na orelha direita: argolinha dourada com uma pedra redonda pendurada.
    /// A cor da pedra identifica a configuração ativa.
    static func drawEarring(_ g: Geo, gem: NSColor) {
        let gold = NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.25, alpha: 1)

        let ring = oval(NSRect(x: g.P(0.765, 0.785).x, y: g.P(0.765, 0.785).y,
                               width: 0.045 * g.s, height: 0.045 * g.s))
        ring.lineWidth = 0.012 * g.s
        gold.setStroke()
        ring.stroke()

        let ball = g.R(0.762, 0.715, 0.06, 0.06)
        gold.setFill()
        oval(ball.insetBy(dx: -0.008 * g.s, dy: -0.008 * g.s)).fill()
        gem.setFill()
        oval(ball).fill()
        NSColor.white.withAlphaComponent(0.8).setFill()
        oval(NSRect(x: ball.minX + ball.width * 0.22, y: ball.minY + ball.height * 0.55,
                    width: ball.width * 0.28, height: ball.height * 0.28)).fill()
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
        draw(in: bg.insetBy(dx: s * 0.06, dy: s * 0.06))
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}
