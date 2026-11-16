import AppKit

// MARK: - O que a coruja está fazendo

enum Activity: Equatable {
    case idle, sleeping                       // estados de base
    case sunrise, sunset, dusk                // sol
    case walking                              // passeio pela tela
    case puppy                                // carinha de filhote (chamar atenção)
    case petted                               // carinho na barriga
    case hoot, flap, yawn, lookAround, hop    // aleatórias
    case nest                                 // descansar no ninho
    case coffee, lunch, snack, party          // por horário
}

/// Animação de horário: toca uma vez por dia, num minuto sorteado dentro da janela.
struct ScheduledAnimation {
    let key: String
    let activity: Activity
    let start: Int          // minutos desde a meia-noite
    let end: Int
    let weekday: Int?       // 1 = domingo ... 6 = sexta (nil = todo dia)
    var fireAt = 0
}

// MARK: - Funções de suavização

private func clamp01(_ x: CGFloat) -> CGFloat { max(0, min(1, x)) }

/// Sobe suave de 0 a 1 entre a e b.
private func smooth(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
    let t = clamp01((x - a) / (b - a))
    return t * t * (3 - 2 * t)
}

/// Sobe e desce (0 → 1 → 0) entre a e b.
private func bump(_ x: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
    guard x > a, x < b else { return 0 }
    return sin((x - a) / (b - a) * .pi)
}

// MARK: - Animador

/// Calcula cada quadro: pose, posição, sol, ninho, objetos e partículas.
/// Não desenha nada; a OwlView lê o estado e desenha.
final class OwlAnimator {
    // Saída (lida pela view)
    private(set) var pose = Pose.asleep
    private(set) var offset = CGPoint.zero          // em unidades da coruja
    private(set) var tilt: CGFloat = 0              // graus
    private(set) var squash: CGFloat = 1            // escala vertical
    private(set) var sun: (pos: CGFloat, alpha: CGFloat)?
    private(set) var sunSpin: CGFloat = 0
    private(set) var nest: CGFloat = 1
    private(set) var prop: Prop?
    private(set) var propPhase: CGFloat = 0
    private(set) var particles: [Particle] = []
    private(set) var activity: Activity = .sleeping

    // Entrada (preenchida pelo app)
    var awake = false
    var mouseLook = CGPoint.zero
    var dragging = false
    var moveWindow: ((CGFloat) -> Bool)?            // move a janela; false = bateu na borda
    var canWalk: (() -> Bool)?

    // Relógio interno
    private var time: Double = 0
    private var started: Double = 0
    private var duration: Double = 0
    private var fired = Set<String>()
    private var nextBlink: Double = 2
    private var blinkEnd: Double = 0
    private var nextRandom: Double = 40
    private var nextAttention: Double
    private var lastRandom: Activity?
    private var nextParticle: Double = 0
    private var lastCycle = -1
    private var walkDir: CGFloat = 1

    // Horários
    private var clockCheck: Double = 0
    private var evening = Settings.isEvening()
    private var schedule: [ScheduledAnimation] = []
    private var scheduleDay = -1

    init() {
        nextAttention = Double.random(in: 15 * 60...30 * 60)
    }

    /// Quadros por segundo de que precisa agora. Parada = poucos quadros (leve).
    var desiredFPS: Double {
        if dragging { return 30 }
        switch activity {
        case .idle: return particles.isEmpty ? 12 : 20
        case .sleeping: return 8
        case .nest: return 10
        default: return 30
        }
    }

    // MARK: Comandos

    func wake() {
        awake = true
        play(.sunrise)
    }

    func sleep() {
        awake = false
        play(.sunset)
    }

    func pet() {
        if awake {
            play(.petted)
        } else {
            spawnHeart()   // dormindo: só um coraçãozinho, sem acordar
        }
    }

    func play(_ a: Activity, duration d: Double? = nil) {
        activity = a
        started = time
        fired.removeAll()
        lastCycle = -1
        duration = d ?? defaultDuration(a)
        if a == .walking {
            walkDir = Bool.random() ? 1 : -1
            if canWalk?() == false { finish() }
        }
    }

    /// Quadro parado (usado quando as animações estão desligadas).
    func staticFrame() {
        activity = awake ? .idle : .sleeping
        pose = awake ? Pose(lid: evening ? 0.3 : 0) : .asleep
        offset = CGPoint(x: 0, y: awake ? 0 : -0.05)
        tilt = 0; squash = 1; sun = nil; prop = nil
        nest = awake ? 0 : 1
        particles.removeAll()
    }

    private func defaultDuration(_ a: Activity) -> Double {
        switch a {
        case .idle, .sleeping: return 0
        case .sunrise, .sunset: return 4.5
        case .dusk: return 5
        case .walking: return Double.random(in: 3...8)
        case .puppy: return 4.5
        case .petted: return 1.8
        case .hoot: return 2
        case .flap: return 1.4
        case .yawn: return 2.6
        case .lookAround: return 3
        case .hop: return 1.2
        case .nest: return Double.random(in: 60...150)
        case .coffee: return 8
        case .lunch: return 9
        case .snack: return 8
        case .party: return 6
        }
    }

    private func finish() {
        if awake {
            activity = .idle
            nextRandom = time + Double.random(in: 20...90)
        } else {
            activity = .sleeping
        }
        started = time
        duration = 0
    }

    // MARK: Quadro a quadro

    func update(_ dt: Double) {
        time += dt
        checkClock()
        if awake && activity == .idle && time >= nextRandom { pickRandom() }

        let t = time - started
        let p = duration > 0 ? CGFloat(min(1, t / duration)) : 0
        let baseLid: CGFloat = evening ? 0.3 : 0

        var pose = Pose()
        pose.lid = awake ? baseLid : 1
        pose.look = awake ? mouseLook : .zero
        var off = CGPoint.zero
        var tilt: CGFloat = 0
        var squash = 1 + 0.012 * CGFloat(sin(time * 2.0))      // respiração
        var sun: (pos: CGFloat, alpha: CGFloat)?
        var nestTarget: CGFloat = awake ? 0 : 1
        var prop: Prop?
        var propPhase: CGFloat = 0

        switch activity {
        case .idle:
            break

        case .sleeping:
            pose.lid = 1
            nestTarget = 1
            off.y = -0.05
            squash = 1 + 0.025 * CGFloat(sin(time * 1.2))
            every(1.7) {
                spawn(.zzz, at: CGPoint(x: 0.70, y: 0.82), vel: CGVector(dx: 0.06, dy: 0.10),
                      life: 2.8, size: 0.10 + CGFloat.random(in: 0...0.04))
            }

        case .sunrise:
            // sol nasce atrás e a coruja se espreguiça
            sun = (smooth(0, 0.7, p), 1 - smooth(0.8, 1, p))
            pose.lid = 1 - smooth(0.25, 0.6, p) * (1 - baseLid)
            let stretch = bump(p, 0.35, 0.9)
            squash += 0.12 * stretch
            pose.wing = stretch
            pose.beakOpen = 0.8 * bump(p, 0.4, 0.75)
            nestTarget = 1 - smooth(0.6, 0.95, p)
            off.y = -0.05 * nestTarget

        case .sunset:
            // sol se põe, os olhos vão fechando e ela se aninha
            sun = (1 - smooth(0.1, 1, p), smooth(0, 0.15, p) * (1 - smooth(0.85, 1, p)))
            pose.lid = baseLid + (1 - baseLid) * smooth(0.3, 0.95, p)
            nestTarget = smooth(0.45, 0.9, p)
            off.y = -0.05 * nestTarget

        case .dusk:
            // anoitecer com ela acordada: sol baixando e olhos um pouco mais baixos
            sun = (1 - smooth(0.1, 1, p), smooth(0, 0.15, p) * (1 - smooth(0.85, 1, p)))
            pose.lid = 0.3 * smooth(0.3, 1, p)

        case .walking:
            let phase = time * 9
            tilt = 7 * CGFloat(sin(phase))
            off.y = 0.03 * abs(CGFloat(sin(phase)))
            pose.step = CGFloat(sin(phase))
            pose.look = CGPoint(x: walkDir * 0.7, y: -0.1)
            if moveWindow?(walkDir * 28 * CGFloat(dt)) == false { duration = t }

        case .puppy:
            // olhos grandes e brilhantes, cabeça inclinada, pulinhos e corações
            let k = smooth(0, 0.12, p) * (1 - smooth(0.85, 1, p))
            pose.puppy = k
            pose.lid = 0
            pose.look = CGPoint(x: 0, y: 0.45 * k)
            tilt = 10 * k
            squash += 0.03 * k
            if p < 0.3 { off.y = 0.07 * abs(sin(p / 0.3 * 2 * .pi)) }
            if once("heart", p > 0.35) { spawnHeart() }
            every(0.45) { if k > 0.5 { spawnSparkle() } }

        case .petted:
            pose.happy = true
            off.y = 0.04 * abs(sin(p * 2 * .pi))
            for (i, at) in [0.1, 0.4, 0.7].enumerated() where once("h\(i)", p > CGFloat(at)) { spawnHeart() }

        case .hoot:
            pose.beakOpen = bump(p, 0.1, 0.5) + bump(p, 0.5, 0.9)
            squash += 0.05 * pose.beakOpen
            for (i, at) in [0.2, 0.6].enumerated() where once("n\(i)", p > CGFloat(at)) {
                spawn(.note, at: CGPoint(x: 0.62, y: 0.55), vel: CGVector(dx: 0.14, dy: 0.18), life: 1.6, size: 0.15)
            }

        case .flap:
            pose.wing = abs(sin(p * .pi * 4)) * (1 - smooth(0.85, 1, p))
            off.y = 0.03 * pose.wing

        case .yawn:
            let b = bump(p, 0.1, 0.85)
            pose.beakOpen = b
            pose.lid = max(baseLid, 0.75 * b)
            squash += 0.06 * b
            tilt = -4 * b

        case .lookAround:
            pose.look = CGPoint(x: 0.9 * sin(p * 2 * .pi), y: 0.2 * sin(p * 4 * .pi))
            tilt = 6 * sin(p * 2 * .pi)

        case .hop:
            off.y = 0.08 * abs(sin(p * 2 * .pi))
            squash -= 0.05 * bump(p, 0.45, 0.55) + 0.05 * bump(p, 0.9, 1)

        case .nest:
            nestTarget = 1 - smooth(0.95, 1, p)
            pose.lid = max(baseLid, 0.5)
            off.y = -0.05 * nest

        case .coffee:
            prop = .mug
            let c = cycle(2.5, t)
            propPhase = bump(c.x, 0.3, 0.8)
            pose.lid = max(baseLid, 0.6 * propPhase)          // fecha os olhos no gole
            every(0.5) {
                spawn(.steam, at: CGPoint(x: 0.17 + CGFloat.random(in: -0.02...0.02), y: 0.40 + propPhase * 0.08),
                      vel: CGVector(dx: 0.01, dy: 0.12), life: 1.2, size: 0.04)
            }

        case .lunch:
            prop = .bowl
            let c = cycle(0.8, t)
            let peck = bump(c.x, 0, 1)
            off.y = -0.06 * peck
            pose.look = CGPoint(x: 0, y: -0.7)
            pose.beakOpen = peck > 0.6 ? 0.5 : 0
            if c.new && t > 0.5 { spawnCrumbs(at: CGPoint(x: 0.5, y: 0.14)) }
            if p > 0.9 { pose.happy = true }

        case .snack:
            prop = .cookie
            propPhase = p
            let c = cycle(1.2, t)
            pose.beakOpen = 0.6 * bump(c.x, 0.2, 0.6)
            pose.look = CGPoint(x: 0.7, y: -0.3)
            if c.new && t > 0.8 { spawnCrumbs(at: CGPoint(x: 0.80, y: 0.26)) }

        case .party:
            prop = .partyHat
            pose.happy = p > 0.2 && p < 0.8
            off.y = 0.06 * abs(sin(p * 4 * .pi))
            pose.wing = 0.5 * abs(sin(p * 4 * .pi))
            every(0.12) { if p < 0.8 { spawnConfetti() } }
        }

        // piscadas (às vezes duplas)
        if awake && !pose.happy && pose.lid < 0.9 {
            if time >= nextBlink {
                blinkEnd = time + 0.13
                nextBlink = time + (Double.random(in: 0...1) < 0.15 ? 0.35 : Double.random(in: 2.5...6.5))
            }
            if time < blinkEnd { pose.lid = 1 }
        }

        // sendo arrastada: bate as asas
        if dragging {
            pose.wing = max(pose.wing, 0.4 + 0.4 * abs(CGFloat(sin(time * 16))))
        }

        if duration > 0 && t >= duration { finish() }

        nest += (nestTarget - nest) * CGFloat(min(1, dt * 4))
        sunSpin += CGFloat(dt) * 0.4
        self.pose = pose
        self.offset = off
        self.tilt = tilt
        self.squash = squash
        self.sun = sun
        self.prop = prop
        self.propPhase = propPhase
        updateParticles(CGFloat(dt))
    }

    // MARK: Escolha aleatória (imprevisível, sem repetir a última)

    private func pickRandom() {
        if Settings.attentionOn && time >= nextAttention {
            nextAttention = time + Double.random(in: 20 * 60...45 * 60)
            play(.puppy)
            return
        }
        var options: [(Activity, Double)] = [
            (.lookAround, 3), (.hoot, 2), (.flap, 2), (.hop, 1.5), (.nest, 1),
            (.yawn, evening ? 2 : 0.3),
        ]
        if Settings.walkingOn && canWalk?() == true { options.append((.walking, 2.5)) }
        options.removeAll { $0.0 == lastRandom }

        let total = options.reduce(0) { $0 + $1.1 }
        var roll = Double.random(in: 0..<total)
        for (a, w) in options {
            roll -= w
            if roll < 0 {
                lastRandom = a
                play(a)
                return
            }
        }
        finish()
    }

    // MARK: Horários (verificados a cada 20 s, não a cada quadro)

    private func checkClock() {
        guard time >= clockCheck else { return }
        clockCheck = time + 20

        let now = Date()
        let day = Calendar.current.ordinality(of: .day, in: .era, for: now) ?? 0
        if day != scheduleDay {
            scheduleDay = day
            buildSchedule(weekday: Calendar.current.component(.weekday, from: now))
        }

        // pôr e nascer do sol com ela acordada
        let ev = Settings.isEvening(now)
        if ev != evening {
            evening = ev
            if Settings.scheduleOn && awake && (activity == .idle || activity == .nest) {
                play(ev ? .dusk : .sunrise)
            }
        }

        guard Settings.scheduleOn, awake, activity == .idle else { return }
        let m = Settings.minutesNow(now)
        for item in schedule where m >= item.fireAt && m <= item.end && !Settings.playedToday(item.key) {
            Settings.markPlayedToday(item.key)
            play(item.activity)
            return
        }
    }

    private func buildSchedule(weekday: Int) {
        let all = [
            ScheduledAnimation(key: "cafe", activity: .coffee, start: 8 * 60 + 30, end: 10 * 60, weekday: nil),
            ScheduledAnimation(key: "almoco", activity: .lunch, start: 12 * 60, end: 13 * 60 + 30, weekday: nil),
            ScheduledAnimation(key: "lanche", activity: .snack, start: 15 * 60 + 30, end: 16 * 60 + 30, weekday: nil),
            ScheduledAnimation(key: "sextou", activity: .party, start: 17 * 60, end: 18 * 60, weekday: 6),
        ]
        schedule = all.filter { $0.weekday == nil || $0.weekday == weekday }.map {
            var item = $0
            item.fireAt = Int.random(in: item.start...max(item.start, item.end - 10))  // minuto sorteado
            return item
        }
    }

    // MARK: Utilitários de tempo

    /// Executa algo no máximo uma vez por animação, quando a condição ficar verdadeira.
    private func once(_ key: String, _ cond: Bool) -> Bool {
        guard cond, !fired.contains(key) else { return false }
        fired.insert(key)
        return true
    }

    /// Executa algo a cada `interval` segundos.
    private func every(_ interval: Double, _ body: () -> Void) {
        if time >= nextParticle {
            nextParticle = time + interval
            body()
        }
    }

    /// Posição (0...1) dentro de um ciclo repetido e se acabou de começar um ciclo novo.
    private func cycle(_ period: Double, _ t: Double) -> (x: CGFloat, new: Bool) {
        let n = Int(t / period)
        let isNew = n != lastCycle
        lastCycle = n
        return (CGFloat(t.truncatingRemainder(dividingBy: period) / period), isNew)
    }

    // MARK: Partículas

    private func spawn(_ kind: ParticleKind, at: CGPoint, vel: CGVector, life: CGFloat, size: CGFloat, hue: CGFloat = 0) {
        guard particles.count < 40 else { return }       // limite para ficar leve
        particles.append(Particle(kind: kind, pos: at, vel: vel, life: life, size: size, hue: hue))
    }

    private func spawnHeart() {
        spawn(.heart, at: CGPoint(x: CGFloat.random(in: 0.35...0.65), y: 0.92),
              vel: CGVector(dx: CGFloat.random(in: -0.05...0.05), dy: 0.22), life: 1.6, size: 0.12)
    }

    private func spawnSparkle() {
        let x: CGFloat = Bool.random() ? CGFloat.random(in: 0.15...0.30) : CGFloat.random(in: 0.70...0.85)
        spawn(.sparkle, at: CGPoint(x: x, y: CGFloat.random(in: 0.55...0.85)),
              vel: CGVector(dx: 0, dy: 0.03), life: 0.7, size: 0.08)
    }

    private func spawnCrumbs(at p: CGPoint) {
        for _ in 0..<3 {
            spawn(.crumb, at: p, vel: CGVector(dx: CGFloat.random(in: -0.15...0.15), dy: CGFloat.random(in: 0.05...0.15)),
                  life: 0.6, size: 0.025)
        }
    }

    private func spawnConfetti() {
        spawn(.confetti, at: CGPoint(x: CGFloat.random(in: 0.1...0.9), y: 1.1),
              vel: CGVector(dx: CGFloat.random(in: -0.08...0.08), dy: -0.35), life: 1.8, size: 0.04,
              hue: CGFloat.random(in: 0...1))
    }

    private func updateParticles(_ dt: CGFloat) {
        guard !particles.isEmpty else { return }
        for i in particles.indices {
            particles[i].pos.x += particles[i].vel.dx * dt
            particles[i].pos.y += particles[i].vel.dy * dt
            particles[i].age += dt
            if particles[i].kind == .crumb { particles[i].vel.dy -= 0.6 * dt }   // migalha cai
        }
        particles.removeAll { $0.age >= $0.life }
    }
}
