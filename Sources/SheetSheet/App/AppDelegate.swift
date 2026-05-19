import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var fnMonitor: FnKeyMonitor?
    private var overlayController: OverlayWindowController?
    private let cardStore = CardStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerLoginItem()
        setupMenuBar()
        setupOverlay()
        setupFnMonitor()
        requestPermissionsIfNeeded()
    }

    // MARK: - Login item

    private func registerLoginItem() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            // Already registered or unavailable — not fatal
        }
    }

    // MARK: - Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "list.bullet.rectangle", accessibilityDescription: "SheetSheet")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Edit Shortcuts", action: #selector(showOverlay), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SheetSheet", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    // MARK: - Overlay

    private func setupOverlay() {
        overlayController = OverlayWindowController(cardStore: cardStore)
    }

    @objc private func showOverlay() {
        overlayController?.toggle()
    }

    // MARK: - Fn monitor

    private func setupFnMonitor() {
        fnMonitor = FnKeyMonitor {
            DispatchQueue.main.async { [weak self] in
                self?.overlayController?.show()
            }
        } onRelease: {
            DispatchQueue.main.async { [weak self] in
                self?.overlayController?.hide()
            }
        }
        fnMonitor?.start()
    }

    // MARK: - Permissions

    private func requestPermissionsIfNeeded() {
        let axOptions = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let axTrusted = AXIsProcessTrustedWithOptions(axOptions)

        // Always request Input Monitoring — CGEventTap needs it on macOS 14+
        // CGRequestListenEventAccess triggers the system TCC prompt automatically
        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
        }

        if !axTrusted {
            let alert = NSAlert()
            alert.messageText = "Accessibility Access Required"
            alert.informativeText = "SheetSheet needs Accessibility access to detect the Fn key. Please grant access in System Settings → Privacy & Security → Accessibility, then relaunch the app."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }
}
