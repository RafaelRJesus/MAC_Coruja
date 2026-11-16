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
