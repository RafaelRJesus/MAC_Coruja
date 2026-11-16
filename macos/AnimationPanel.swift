import AppKit

// MARK: - Painel das animações (abre ao clicar na orelha esquerda, a sem brinco)

final class AnimationPanelController: NSViewController {
    weak var app: AppDelegate?

    private let master = NSSwitch()
    private let walking = NSButton(checkboxWithTitle: "Passear pela tela", target: nil, action: nil)
    private let attention = NSButton(checkboxWithTitle: "Chamar atenção de vez em quando", target: nil, action: nil)
    private let schedule = NSButton(checkboxWithTitle: "Animações por horário (café, almoço, lanche, sol)",
                                    target: nil, action: nil)
    private let sizeControl = NSSegmentedControl(labels: OwlSize.allCases.map { $0.title },
                                                 trackingMode: .selectOne, target: nil, action: nil)
    private let playPopup = NSPopUpButton(frame: .zero, pullsDown: true)

    /// Animações que dá para ver na hora, pelo menu "Ver agora".
    private let playable: [(String, Activity)] = [
        ("Carinha de filhote", .puppy), ("Piar", .hoot), ("Bater asas", .flap), ("Pulinho", .hop),
        ("Olhar em volta", .lookAround), ("Bocejar", .yawn), ("Descansar no ninho", .nest),
        ("Passear", .walking), ("Café", .coffee), ("Almoço", .lunch), ("Lanche", .snack),
        ("Festa de sexta", .party), ("Nascer do sol", .sunrise), ("Pôr do sol", .dusk),
    ]

    override func loadView() {
        let title = NSTextField(labelWithString: "Animações")
        title.font = .boldSystemFont(ofSize: 13)
        master.target = self
        master.action = #selector(masterChanged)
        let header = NSStackView(views: [title, NSView(), master])
        header.distribution = .fill

        for box in [walking, attention, schedule] {
            box.target = self
            box.action = #selector(optionsChanged)
        }

        sizeControl.target = self
        sizeControl.action = #selector(sizeChanged)
        let sizeRow = NSStackView(views: [NSTextField(labelWithString: "Tamanho"), sizeControl])

        playPopup.addItem(withTitle: "Ver uma animação agora…")
        playPopup.addItems(withTitles: playable.map { $0.0 })
        playPopup.target = self
        playPopup.action = #selector(playChosen)

        let hint = NSTextField(wrappingLabelWithString:
            "Desligadas, a coruja fica parada e não usa processamento.")
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 11)

        let stack = NSStackView(views: [header, walking, attention, schedule, sizeRow, playPopup, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        stack.widthAnchor.constraint(equalToConstant: 330).isActive = true
        header.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28).isActive = true
        view = stack
        loadValues()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        loadValues()
    }

    private func loadValues() {
        master.state = Settings.animationsOn ? .on : .off
        walking.state = Settings.walkingOn ? .on : .off
        attention.state = Settings.attentionOn ? .on : .off
        schedule.state = Settings.scheduleOn ? .on : .off
        sizeControl.selectedSegment = Settings.size.rawValue
        refreshEnabled()
    }

    private func refreshEnabled() {
        let on = master.state == .on
        for c in [walking, attention, schedule] as [NSControl] { c.isEnabled = on }
        playPopup.isEnabled = on
        preferredContentSize = view.fittingSize
    }

    @objc private func masterChanged() {
        Settings.animationsOn = master.state == .on
        refreshEnabled()
        app?.applyAnimationSettings()
    }

    @objc private func optionsChanged() {
        Settings.walkingOn = walking.state == .on
        Settings.attentionOn = attention.state == .on
        Settings.scheduleOn = schedule.state == .on
    }

    @objc private func sizeChanged() {
        Settings.size = OwlSize(rawValue: sizeControl.selectedSegment) ?? .small
        app?.applySize()
    }

    @objc private func playChosen() {
        let i = playPopup.indexOfSelectedItem - 1          // o item 0 é o título
        guard i >= 0, i < playable.count else { return }
        app?.playNow(playable[i].1)
        app?.animationPopover.performClose(nil)
    }
}
