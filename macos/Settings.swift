import AppKit

// MARK: - Configurações (salvas entre aberturas do app)

enum LimitMode: Int {
    case none = 0      // fica acordada até eu fechar os olhos
    case timer = 1     // contagem regressiva
    case clock = 2     // horário fixo

    /// Cor da pedra do brinco para cada configuração.
    var gemColor: NSColor {
        switch self {
        case .none:  return NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.10, alpha: 1) // laranja
        case .timer: return NSColor(calibratedRed: 0.25, green: 0.55, blue: 0.95, alpha: 1) // azul
        case .clock: return NSColor(calibratedRed: 0.20, green: 0.75, blue: 0.45, alpha: 1) // verde
        }
    }
}

enum Settings {
    private static let d = UserDefaults.standard

    static var mode: LimitMode {
        get { LimitMode(rawValue: d.integer(forKey: "mode")) ?? .none }
        set { d.set(newValue.rawValue, forKey: "mode") }
    }

    /// Duração do temporizador, em minutos (padrão: 1 h).
    static var timerMinutes: Int {
        get { let v = d.integer(forKey: "timerMinutes"); return v > 0 ? v : 60 }
        set { d.set(max(1, newValue), forKey: "timerMinutes") }
    }

    /// Horário para dormir, em minutos desde a meia-noite (padrão: 18:00).
    static var clockMinutes: Int {
        get { d.object(forKey: "clockMinutes") as? Int ?? 18 * 60 }
        set { d.set(newValue, forKey: "clockMinutes") }
    }

    /// Calcula quando a coruja deve dormir a partir de agora (nil = sem limite).
    static func deadline(from now: Date = Date()) -> Date? {
        switch mode {
        case .none:
            return nil
        case .timer:
            return now.addingTimeInterval(TimeInterval(timerMinutes * 60))
        case .clock:
            let cal = Calendar.current
            var comps = cal.dateComponents([.year, .month, .day], from: now)
            comps.hour = clockMinutes / 60
            comps.minute = clockMinutes % 60
            guard let today = cal.date(from: comps) else { return nil }
            // Se o horário de hoje já passou, vale para amanhã
            return today > now ? today : cal.date(byAdding: .day, value: 1, to: today)
        }
    }
}

func formatRemaining(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds.rounded(.up)))
    return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
}

// MARK: - Configurações das animações (orelha esquerda)

enum OwlSize: Int, CaseIterable {
    case small = 0, medium = 1, large = 2

    /// Tamanho da coruja em pontos (a janela é um pouco maior para os efeitos).
    var points: CGFloat { [70, 95, 125][rawValue] }
    var title: String { ["Pequena", "Média", "Grande"][rawValue] }
}

extension Settings {
    private static var defaults: UserDefaults { .standard }

    private static func bool(_ key: String, _ fallback: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? fallback
    }

    /// Chave geral: com ela desligada a coruja fica parada (zero processamento).
    static var animationsOn: Bool {
        get { bool("animationsOn", true) }
        set { defaults.set(newValue, forKey: "animationsOn") }
    }

    /// Andar pela tela de vez em quando.
    static var walkingOn: Bool {
        get { bool("walkingOn", true) }
        set { defaults.set(newValue, forKey: "walkingOn") }
    }

    /// Chamar atenção com carinha de filhote de vez em quando.
    static var attentionOn: Bool {
        get { bool("attentionOn", true) }
        set { defaults.set(newValue, forKey: "attentionOn") }
    }

    /// Animações por horário (café, almoço, lanche, nascer e pôr do sol).
    static var scheduleOn: Bool {
        get { bool("scheduleOn", true) }
        set { defaults.set(newValue, forKey: "scheduleOn") }
    }

    static var size: OwlSize {
        get { OwlSize(rawValue: defaults.object(forKey: "size") as? Int ?? 0) ?? .small }
        set { defaults.set(newValue.rawValue, forKey: "size") }
    }

    /// Nascer e pôr do sol, em minutos desde a meia-noite.
    static var sunriseMinutes: Int {
        get { defaults.object(forKey: "sunrise") as? Int ?? 6 * 60 }
        set { defaults.set(newValue, forKey: "sunrise") }
    }
    static var sunsetMinutes: Int {
        get { defaults.object(forKey: "sunset") as? Int ?? 18 * 60 + 30 }
        set { defaults.set(newValue, forKey: "sunset") }
    }

    static func minutesNow(_ date: Date = Date()) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Noite: entre o pôr e o nascer do sol (olhos um pouco mais baixos).
    static func isEvening(_ date: Date = Date()) -> Bool {
        let m = minutesNow(date)
        return m >= sunsetMinutes || m < sunriseMinutes
    }

    /// Guarda que uma animação de horário já tocou hoje (para tocar só uma vez por dia).
    static func playedToday(_ key: String) -> Bool {
        defaults.string(forKey: "played." + key) == dayStamp()
    }
    static func markPlayedToday(_ key: String) {
        defaults.set(dayStamp(), forKey: "played." + key)
    }
    private static func dayStamp() -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}
