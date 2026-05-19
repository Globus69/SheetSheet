import CoreGraphics
import Foundation
import OSLog

private let log = Logger(subsystem: "com.sheetsheet.app", category: "FnMonitor")

/// Detects a Fn key long-press (≥ 1 second) via a CGEventTap and fires callbacks.
final class FnKeyMonitor {
    private var eventTap: CFMachPort?
    private var pendingWork: DispatchWorkItem?
    private var longPressDidFire = false
    private let onLongPress: () -> Void
    private let onRelease: () -> Void

    // NX_SECONDARYFNMASK — set in flagsChanged on older keyboards
    private let fnMask = CGEventFlags(rawValue: 0x00800000)
    // Globe/Fn keycodes: 179 (kVK_Globe, Apple Silicon) and 63 (kVK_Function, Intel)
    private let globeKeycodes: Set<Int64> = [179, 63]

    init(onLongPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
        self.onLongPress = onLongPress
        self.onRelease = onRelease
    }

    func start() {
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return nil }
            let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            // Re-enable the tap if macOS disabled it (listenOnly taps can still be disabled)
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
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        pendingWork?.cancel()
    }

    private func handle(type: CGEventType, event: CGEvent) {
        let kc = event.getIntegerValueField(.keyboardEventKeycode)

        switch type {
        case .flagsChanged:
            // Older keyboards: Fn generates flagsChanged with NX_SECONDARYFNMASK
            let flags = event.flags
            let hasFn = flags.contains(fnMask)
            log.info("flagsChanged keycode=\(kc) flags=0x\(String(flags.rawValue, radix: 16)) hasFn=\(hasFn)")
            if hasFn { armLongPress() } else { cancelAndMaybeRelease() }

        case .keyDown where globeKeycodes.contains(kc):
            // Apple Silicon / newer keyboards: Globe key sends keyDown/keyUp
            log.info("Globe/Fn keyDown keycode=\(kc)")
            armLongPress()

        case .keyUp where globeKeycodes.contains(kc):
            log.info("Globe/Fn keyUp keycode=\(kc)")
            cancelAndMaybeRelease()

        default:
            break
        }
    }

    private func armLongPress() {
        longPressDidFire = false
        let work = DispatchWorkItem { [weak self] in
            self?.longPressDidFire = true
            self?.onLongPress()
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func cancelAndMaybeRelease() {
        pendingWork?.cancel()
        pendingWork = nil
        if longPressDidFire {
            longPressDidFire = false
            onRelease()
        }
    }
}
