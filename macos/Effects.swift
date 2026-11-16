import AppKit

// MARK: - Partículas (pequenos efeitos que sobem e somem)

enum ParticleKind {
    case heart, zzz, note, sparkle, steam, crumb, confetti
}

struct Particle {
    var kind: ParticleKind
    var pos: CGPoint          // em unidades da coruja (0...1)
    var vel: CGVector         // unidades por segundo
    var life: CGFloat         // segundos
    var size: CGFloat         // em unidades da coruja
    var age: CGFloat = 0
    var hue: CGFloat = 0      // cor do confete
}

// MARK: - Objetos que aparecem nas animações

enum Prop {
    case mug        // café da manhã
    case bowl       // almoço
    case cookie     // lanche da tarde
    case partyHat   // sexta-feira
}

enum Effects {
    static let pink = NSColor(calibratedRed: 0.98, green: 0.42, blue: 0.58, alpha: 1)
    static let nestColor = NSColor(calibratedRed: 0.55, green: 0.40, blue: 0.22, alpha: 1)
    static let nestDark = NSColor(calibratedRed: 0.40, green: 0.28, blue: 0.14, alpha: 1)

    /// Desenha algo com transparência (alpha 0...1) sem precisar mudar cada cor.
    static func withAlpha(_ a: CGFloat, _ body: () -> Void) {
        guard a > 0.01 else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setAlpha(min(1, a))
        body()
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: Partículas

    static func draw(_ p: Particle, g: Geo) {
        let fade = max(0, 1 - p.age / p.life)
        let c = g.P(p.pos.x, p.pos.y)
        let s = p.size * g.s
        withAlpha(fade) {
            switch p.kind {
            case .heart:
                pink.setFill()
                heartPath(center: c, size: s).fill()
            case .zzz:
                text("z", at: c, size: s, color: NSColor(calibratedWhite: 0.95, alpha: 1))
            case .note:
                text("♪", at: c, size: s, color: NSColor(calibratedRed: 0.55, green: 0.75, blue: 1, alpha: 1))
            case .sparkle:
                NSColor(calibratedRed: 1, green: 0.95, blue: 0.6, alpha: 1).setFill()
                star(center: c, size: s).fill()
            case .steam:
                NSColor(calibratedWhite: 1, alpha: 0.6).setFill()
                Owl.oval(NSRect(x: c.x - s / 2, y: c.y - s / 2, width: s, height: s)).fill()
            case .crumb:
                NSColor(calibratedRed: 0.85, green: 0.65, blue: 0.35, alpha: 1).setFill()
                Owl.oval(NSRect(x: c.x - s / 2, y: c.y - s / 2, width: s, height: s)).fill()
            case .confetti:
                NSColor(calibratedHue: p.hue, saturation: 0.7, brightness: 1, alpha: 1).setFill()
                NSBezierPath(rect: NSRect(x: c.x, y: c.y, width: s, height: s * 0.5)).fill()
            }
        }
    }

    static func text(_ t: String, at c: NSPoint, size: CGFloat, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: max(6, size)),
            .foregroundColor: color,
        ]
        (t as NSString).draw(at: NSPoint(x: c.x - size * 0.3, y: c.y - size * 0.5), withAttributes: attrs)
    }

    static func heartPath(center c: NSPoint, size s: CGFloat) -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: c.x, y: c.y - s * 0.5))
        p.curve(to: NSPoint(x: c.x - s * 0.5, y: c.y + s * 0.15),
                controlPoint1: NSPoint(x: c.x - s * 0.15, y: c.y - s * 0.25),
                controlPoint2: NSPoint(x: c.x - s * 0.5, y: c.y - s * 0.1))
        p.curve(to: NSPoint(x: c.x, y: c.y + s * 0.2),
                controlPoint1: NSPoint(x: c.x - s * 0.5, y: c.y + s * 0.5),
                controlPoint2: NSPoint(x: c.x - s * 0.05, y: c.y + s * 0.5))
        p.curve(to: NSPoint(x: c.x + s * 0.5, y: c.y + s * 0.15),
                controlPoint1: NSPoint(x: c.x + s * 0.05, y: c.y + s * 0.5),
                controlPoint2: NSPoint(x: c.x + s * 0.5, y: c.y + s * 0.5))
        p.curve(to: NSPoint(x: c.x, y: c.y - s * 0.5),
                controlPoint1: NSPoint(x: c.x + s * 0.5, y: c.y - s * 0.1),
                controlPoint2: NSPoint(x: c.x + s * 0.15, y: c.y - s * 0.25))
        p.close()
        return p
    }

    static func star(center c: NSPoint, size s: CGFloat) -> NSBezierPath {
        let p = NSBezierPath()
        let r = s / 2, k = r * 0.3
        p.move(to: NSPoint(x: c.x, y: c.y + r))
        p.line(to: NSPoint(x: c.x + k, y: c.y + k))
        p.line(to: NSPoint(x: c.x + r, y: c.y))
        p.line(to: NSPoint(x: c.x + k, y: c.y - k))
        p.line(to: NSPoint(x: c.x, y: c.y - r))
        p.line(to: NSPoint(x: c.x - k, y: c.y - k))
        p.line(to: NSPoint(x: c.x - r, y: c.y))
        p.line(to: NSPoint(x: c.x - k, y: c.y + k))
        p.close()
        return p
    }

    // MARK: Sol (nasce atrás da coruja e se põe atrás dela)

    /// progress: 0 = escondido atrás da coruja, 1 = alto, à esquerda.
    static func drawSun(g: Geo, progress: CGFloat, spin: CGFloat) {
        let p = max(0, min(1, progress))
        let center = g.P(0.62 - 0.50 * p, 0.25 + 0.60 * p)
        let r = 0.11 * g.s
        // cor vai do laranja (horizonte) para o amarelo (alto)
        let color = NSColor(calibratedRed: 1, green: 0.55 + 0.35 * p, blue: 0.15 + 0.2 * p, alpha: 1)

        withAlpha(0.35 * p + 0.15) {
            color.setFill()
            Owl.oval(NSRect(x: center.x - r * 1.7, y: center.y - r * 1.7, width: r * 3.4, height: r * 3.4)).fill()
        }
        let rays = NSBezierPath()
        rays.lineWidth = 0.02 * g.s
        rays.lineCapStyle = .round
        for i in 0..<8 {
            let a = (CGFloat(i) / 8) * 2 * .pi + spin
            rays.move(to: NSPoint(x: center.x + cos(a) * r * 1.3, y: center.y + sin(a) * r * 1.3))
            rays.line(to: NSPoint(x: center.x + cos(a) * r * 1.7, y: center.y + sin(a) * r * 1.7))
        }
        color.setStroke(); rays.stroke()
        color.setFill()
        Owl.oval(NSRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)).fill()
    }

    // MARK: Ninho (na frente da coruja, cobrindo pés e barriga)

    static func drawNest(g: Geo, amount: CGFloat) {
        // sobe de baixo quando aparece
        let dy = (1 - amount) * 0.25
        withAlpha(amount) {
            nestColor.setFill()
            let bowl = NSBezierPath()
            bowl.move(to: g.P(0.08, 0.20 - dy))
            bowl.curve(to: g.P(0.92, 0.20 - dy),
                       controlPoint1: g.P(0.10, -0.08 - dy),
                       controlPoint2: g.P(0.90, -0.08 - dy))
            bowl.close()
            bowl.fill()
            nestDark.setFill()
            Owl.oval(g.R(0.07, 0.15 - dy, 0.86, 0.09)).fill()
            // gravetos
            let twigs = NSBezierPath()
            twigs.lineWidth = 0.012 * g.s
            twigs.lineCapStyle = .round
            let lines: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (0.12, 0.14, 0.40, 0.04), (0.30, 0.17, 0.62, 0.06), (0.55, 0.15, 0.88, 0.12),
                (0.20, 0.06, 0.48, 0.13), (0.50, 0.03, 0.80, 0.14), (0.05, 0.19, 0.22, 0.22),
                (0.78, 0.22, 0.95, 0.18),
            ]
            for (x1, y1, x2, y2) in lines {
                twigs.move(to: g.P(x1, y1 - dy))
                twigs.line(to: g.P(x2, y2 - dy))
            }
            nestDark.setStroke()
            twigs.stroke()
        }
    }

    // MARK: Objetos

    static func drawProp(_ prop: Prop, g: Geo, phase: CGFloat) {
        switch prop {
        case .mug:
            // canequinha na asa esquerda, levanta um pouco ao tomar um gole (phase 0...1)
            let lift = phase * 0.08
            let cup = g.R(0.10, 0.22 + lift, 0.15, 0.14)
            NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.88, alpha: 1).setFill()
            NSBezierPath(roundedRect: cup, xRadius: 0.02 * g.s, yRadius: 0.02 * g.s).fill()
            NSColor(calibratedRed: 0.45, green: 0.28, blue: 0.15, alpha: 1).setFill()
            NSBezierPath(rect: NSRect(x: cup.minX + 0.015 * g.s, y: cup.maxY - 0.03 * g.s,
                                      width: cup.width - 0.03 * g.s, height: 0.02 * g.s)).fill()
            let handle = Owl.oval(NSRect(x: cup.minX - 0.05 * g.s, y: cup.midY - 0.035 * g.s,
                                         width: 0.07 * g.s, height: 0.07 * g.s))
            handle.lineWidth = 0.015 * g.s
            NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.88, alpha: 1).setStroke()
            handle.stroke()
        case .bowl:
            // tigelinha com sementes na frente da coruja
            let bowl = NSBezierPath()
            bowl.move(to: g.P(0.30, 0.10))
            bowl.curve(to: g.P(0.70, 0.10), controlPoint1: g.P(0.32, -0.02), controlPoint2: g.P(0.68, -0.02))
            bowl.close()
            NSColor(calibratedRed: 0.30, green: 0.55, blue: 0.85, alpha: 1).setFill()
            bowl.fill()
            NSColor(calibratedRed: 0.90, green: 0.75, blue: 0.40, alpha: 1).setFill()
            Owl.oval(g.R(0.32, 0.075, 0.36, 0.05)).fill()
        case .cookie:
            // biscoito na asa direita, com mordidas conforme a fase
            let c = g.R(0.76, 0.24, 0.15, 0.15)
            NSGraphicsContext.saveGraphicsState()
            // mordida: recorta um pedaço só do biscoito (tudo menos o círculo da mordida)
            if phase > 0.3 {
                let clip = NSBezierPath(rect: c.insetBy(dx: -g.s, dy: -g.s))
                clip.append(Owl.oval(g.R(0.86, 0.33, 0.07 + phase * 0.03, 0.07 + phase * 0.03)))
                clip.windingRule = .evenOdd
                clip.addClip()
            }
            NSColor(calibratedRed: 0.82, green: 0.60, blue: 0.32, alpha: 1).setFill()
            Owl.oval(c).fill()
            NSColor(calibratedRed: 0.35, green: 0.20, blue: 0.10, alpha: 1).setFill()
            for (x, y) in [(0.80, 0.33), (0.85, 0.28), (0.79, 0.26)] as [(CGFloat, CGFloat)] {
                Owl.oval(g.R(x, y, 0.02, 0.02)).fill()
            }
            NSGraphicsContext.restoreGraphicsState()
        case .partyHat:
            // chapeuzinho de festa entre as orelhas
            let hat = Owl.triangle(g.P(0.40, 0.83), g.P(0.60, 0.83), g.P(0.52, 1.05))
            NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.95, alpha: 1).setFill()
            hat.fill()
            NSColor(calibratedRed: 1, green: 0.85, blue: 0.3, alpha: 1).setFill()
            Owl.oval(g.R(0.495, 1.02, 0.05, 0.05)).fill()
        }
    }
}
