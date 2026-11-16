import AppKit
import IOKit.pwr_mgt

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
