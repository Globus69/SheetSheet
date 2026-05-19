import CoreGraphics
import Foundation
import OSLog

private let log = Logger(subsystem: "com.sheetsheet.app", category: "FnMonitor")

/// Shows overlay when Control+Option are held simultaneously; hides when either is released.
final class FnKeyMonitor {
    private var eventTap: CFMachPort?
    private let onActivate: () -> Void
    private let onRelease: () -> Void

    private var ctrlDown = false
    private var optionDown = false
    private var overlayActive = false

    init(onActivate: @escaping () -> Void, onRelease: @escaping () -> Void) {
        self.onActivate = onActivate
        self.onRelease = onRelease
    }

    func start() {
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return nil }
            let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = monitor.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                return nil
            }
            monitor.handle(type: type, event: event)
            return Unmanaged.passRetained(event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let eventMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        )

        if eventTap == nil {
            log.error("CGEventTap could not be created — check Accessibility permissions")
        } else {
            log.info("CGEventTap created successfully")
        }

        guard let tap = eventTap else { return }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
    }

    private func handle(type: CGEventType, event: CGEvent) {
        guard type == .flagsChanged else { return }
        let flags = event.flags
        ctrlDown = flags.contains(.maskControl)
        optionDown = flags.contains(.maskAlternate)
        log.info("flagsChanged ctrl=\(self.ctrlDown) option=\(self.optionDown)")
        updateOverlay()
    }

    private func updateOverlay() {
        if ctrlDown && optionDown && !overlayActive {
            overlayActive = true
            onActivate()
        } else if overlayActive && (!ctrlDown || !optionDown) {
            overlayActive = false
            onRelease()
        }
    }
}
