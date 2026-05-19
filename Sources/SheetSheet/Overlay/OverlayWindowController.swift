import AppKit
import SwiftUI

final class OverlayWindowController {
    private var panel: NSPanel?
    private let cardStore: CardStore

    init(cardStore: CardStore) {
        self.cardStore = cardStore
    }

    // Called from menu bar — steals focus so user can type immediately
    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            if panel == nil { panel = makePanel() }
            guard let panel else { return }
            positionPanel(panel)
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // Called on Fn long-press — shows without stealing focus so auto-hide on release works
    func show() {
        if panel == nil { panel = makePanel() }
        guard let panel else { return }
        positionPanel(panel)
        panel.orderFront(nil)
    }

    // Called on Fn release — hides unless user has clicked into the panel
    func hideOnFnRelease() {
        guard let panel, panel.isVisible else { return }
        if panel.isKeyWindow { return }   // user clicked in — pin until Escape / next Fn press
        panel.orderOut(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func positionPanel(_ panel: NSPanel) {
        if let screen = NSScreen.main {
            panel.setFrame(screen.visibleFrame.insetBy(dx: 40, dy: 40), display: false)
        }
    }

    private func makePanel() -> NSPanel {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let inset: CGFloat = 40
        let p = EscapablePanel(
            contentRect: screenFrame.insetBy(dx: inset, dy: inset),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.onEscape = { [weak self] in self?.hide() }

        let blur = NSVisualEffectView(frame: p.contentView!.bounds)
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.autoresizingMask = [.width, .height]
        p.contentView?.addSubview(blur)

        let host = NSHostingView(rootView: OverlayView(cardStore: cardStore))
        host.frame = p.contentView!.bounds
        host.autoresizingMask = [.width, .height]
        p.contentView?.addSubview(host)

        return p
    }
}

// NSPanel subclass that closes on Escape
private final class EscapablePanel: NSPanel {
    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }

    override var canBecomeKey: Bool { true }
}
