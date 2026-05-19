import CoreGraphics
import Foundation
import OSLog

private let log = Logger(subsystem: "com.sheetsheet.app", category: "FnMonitor")

/// Shows overlay when Fn+Control are held simultaneously; hides when either is released.
final class FnKeyMonitor {
    private var eventTap: CFMachPort?
    private let onActivate: () -> Void
    private let onRelease: () -> Void

    // NX_SECONDARYFNMASK — set in flagsChanged on older keyboards when Fn is down
    private let fnMask = CGEventFlags(rawValue: 0x00800000)
    // Globe/Fn keycodes: 179 (kVK_Globe, Apple Silicon) and 63 (kVK_Function, Intel)
    private let globeKeycodes: Set<Int64> = [179, 63]

    private var fnDown = false
    private var ctrlDown = false
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
        let eventMask = CGEventMask(
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)
        )
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        )

        if eventTap == nil {
            log.error("CGEventTap could not be created — check Accessibility + Input Monitoring permissions")
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
        let kc = event.getIntegerValueField(.keyboardEventKeycode)

        switch type {
        case .flagsChanged:
            let flags = event.flags
            fnDown = flags.contains(fnMask)
            ctrlDown = flags.contains(.maskControl)
            log.info("flagsChanged kc=\(kc) fn=\(self.fnDown) ctrl=\(self.ctrlDown)")
            updateOverlay()

        case .keyDown where globeKeycodes.contains(kc):
            fnDown = true
            log.info("Globe keyDown kc=\(kc)")
            updateOverlay()

        case .keyUp where globeKeycodes.contains(kc):
            fnDown = false
            log.info("Globe keyUp kc=\(kc)")
            updateOverlay()

        default:
            break
        }
    }

    private func updateOverlay() {
        if fnDown && ctrlDown && !overlayActive {
            overlayActive = true
            onActivate()
        } else if overlayActive && (!fnDown || !ctrlDown) {
            overlayActive = false
            onRelease()
        }
    }
}
