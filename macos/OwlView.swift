import AppKit

// MARK: - View da coruja

final class OwlView: NSView {
    var eyesOpen = false { didSet { needsDisplay = true } }
    var blinking = false { didSet { needsDisplay = true } }
    var gem: NSColor = LimitMode.none.gemColor { didSet { needsDisplay = true } }
    var onToggle: (() -> Void)?
    var onRightEar: ((NSRect) -> Void)?

    var rightEarRect: NSRect { Owl.rightEarArea(in: bounds) }

    override func draw(_ dirtyRect: NSRect) {
        Owl.draw(in: bounds, eyesOpen: eyesOpen && !blinking, gem: gem)
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if rightEarRect.contains(p) {
            onRightEar?(rightEarRect)
        } else if Owl.eyeAreas(in: bounds).contains(where: { $0.contains(p) }) {
            onToggle?()
        } else {
            window?.performDrag(with: event)   // arrastar a coruja pela tela
        }
    }

    override func resetCursorRects() {
        for e in Owl.eyeAreas(in: bounds) { addCursorRect(e, cursor: .pointingHand) }
        addCursorRect(rightEarRect, cursor: .pointingHand)
    }
}

final class OwlWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
