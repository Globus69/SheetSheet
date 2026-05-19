import CoreGraphics
import Foundation

/// Detects a Fn key long-press (≥ 1 second) via a CGEventTap and fires callbacks.
final class FnKeyMonitor {
    private var eventTap: CFMachPort?
    private var pendingWork: DispatchWorkItem?
    private var longPressDidFire = false
    private let onLongPress: () -> Void
    private let onRelease: () -> Void

    // NX_SECONDARYFNMASK = 0x00800000 — the bit set in flagsChanged events when Fn is down
    private let fnMask = CGEventFlags(rawValue: 0x00800000)

    init(onLongPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
        self.onLongPress = onLongPress
        self.onRelease = onRelease
    }

    func start() {
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passRetained(event) }
            // passUnretained: AppDelegate owns FnKeyMonitor strongly; no retain needed here
            let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.handle(type: type, event: event)
            return Unmanaged.passRetained(event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.flagsChanged.rawValue),
            callback: callback,
            userInfo: selfPtr
        )

        if eventTap == nil {
            // CGEventTap creation fails silently when Accessibility is not granted
            print("[SheetSheet] CGEventTap could not be created — Accessibility permission missing?")
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
        guard type == .flagsChanged else { return }
        let flags = event.flags

        if flags.contains(fnMask) {
            longPressDidFire = false
            let work = DispatchWorkItem { [weak self] in
                self?.longPressDidFire = true
                self?.onLongPress()
            }
            pendingWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
        } else {
            pendingWork?.cancel()
            pendingWork = nil
            // Only notify release if the long-press actually fired
            if longPressDidFire {
                longPressDidFire = false
                onRelease()
            }
        }
    }
}
