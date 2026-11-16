import AppKit

// MARK: - Painel de configurações (abre ao clicar na orelha direita)

final class SettingsViewController: NSViewController {
    weak var app: AppDelegate?

    private let modeControl = NSSegmentedControl(labels: ["Sem limite", "Temporizador", "Horário"],
                                                 trackingMode: .selectOne, target: nil, action: nil)
    private let hoursPopup = NSPopUpButton()
    private let minutesPopup = NSPopUpButton()
    private let clockPicker = NSDatePicker()
    private let statusLabel = NSTextField(labelWithString: "")
    private let applyButton = NSButton(title: "Aplicar", target: nil, action: nil)
    private var timerRow: NSStackView!
    private var clockRow: NSStackView!
    private var liveTimer: Timer?

    override func loadView() {
        let title = NSTextField(labelWithString: "Quando a coruja deve dormir?")
        title.font = .boldSystemFont(ofSize: 13)

        modeControl.target = self
        modeControl.action = #selector(modeChanged)

        // Temporizador: horas e minutos (de 5 em 5)
        hoursPopup.addItems(withTitles: (0...12).map { "\($0) h" })
        minutesPopup.addItems(withTitles: stride(from: 0, through: 55, by: 5).map { "\($0) min" })
        for popup in [hoursPopup, minutesPopup] {
            popup.target = self
            popup.action = #selector(valuesChanged)
        }
        timerRow = NSStackView(views: [NSTextField(labelWithString: "Dormir em"), hoursPopup, minutesPopup])

        // Horário fixo
        clockPicker.datePickerStyle = .textFieldAndStepper
        clockPicker.datePickerElements = .hourMinute
        clockPicker.target = self
        clockPicker.action = #selector(valuesChanged)
        clockRow = NSStackView(views: [NSTextField(labelWithString: "Dormir às"), clockPicker])

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)

        applyButton.bezelStyle = .rounded
        applyButton.keyEquivalent = "\r"
        applyButton.target = self
        applyButton.action = #selector(apply)

        let stack = NSStackView(views: [title, modeControl, timerRow, clockRow, statusLabel, applyButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        stack.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        view = stack

        loadValues()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        loadValues()
        // Mantém a contagem regressiva atualizada enquanto o painel está aberto
        liveTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        liveTimer?.invalidate()
        liveTimer = nil
    }

    private func loadValues() {
        modeControl.selectedSegment = Settings.mode.rawValue
        let m = Settings.timerMinutes
        hoursPopup.selectItem(at: min(12, m / 60))
        minutesPopup.selectItem(at: (m % 60) / 5)
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = Settings.clockMinutes / 60
        comps.minute = Settings.clockMinutes % 60
        clockPicker.dateValue = Calendar.current.date(from: comps) ?? Date()
        refresh()
    }

    @objc private func modeChanged() {
        Settings.mode = LimitMode(rawValue: modeControl.selectedSegment) ?? .none
        app?.owl.gem = Settings.mode.gemColor
        refresh()
    }

    @objc private func valuesChanged() {
        Settings.timerMinutes = max(5, hoursPopup.indexOfSelectedItem * 60 + minutesPopup.indexOfSelectedItem * 5)
        let c = Calendar.current.dateComponents([.hour, .minute], from: clockPicker.dateValue)
        Settings.clockMinutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        refresh()
    }

    /// Salva e acorda a coruja com o limite escolhido (ou reinicia a contagem se já estiver acordada).
    @objc private func apply() {
        valuesChanged()
        app?.wakeOwl()
        app?.popover.performClose(nil)
    }

    private func refresh() {
        let mode = LimitMode(rawValue: modeControl.selectedSegment) ?? .none
        timerRow.isHidden = mode != .timer
        clockRow.isHidden = mode != .clock
        let awake = app?.keeper.active ?? false
        applyButton.title = awake ? "Aplicar" : "Acordar a coruja"
        statusLabel.stringValue = app?.statusText ?? ""
        preferredContentSize = view.fittingSize
    }
}
