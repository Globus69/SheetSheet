import AppKit
import SwiftUI

struct KeyCaptureField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Taste drücken…"

    func makeNSView(context: Context) -> KeyCaptureView {
        let v = KeyCaptureView()
        v.placeholder = placeholder
        v.onCapture = { text = $0 }
        v.onClear   = { text = "" }
        return v
    }

    func updateNSView(_ v: KeyCaptureView, context: Context) {
        v.displayText = text
        v.setNeedsDisplay(v.bounds)
    }
}

final class KeyCaptureView: NSView {
    var placeholder: String = "Taste drücken…"
    var displayText: String = "" { didSet { setNeedsDisplay(bounds) } }
    var onCapture: ((String) -> Void)?
    var onClear:   (() -> Void)?

    private var isFocused = false { didSet { setNeedsDisplay(bounds) } }
    private var previousFlags: NSEvent.ModifierFlags = []

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func becomeFirstResponder() -> Bool {
        isFocused = true
        previousFlags = NSEvent.ModifierFlags()
        return super.becomeFirstResponder()
    }
    override func resignFirstResponder() -> Bool {
        isFocused = false
        return super.resignFirstResponder()
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    // MARK: - Key capture

    // Modifier keys: flagsChanged fires on press AND release.
    // We append only on press (newly added bit).
    private let fnMask: UInt = 0x00800000  // NX_SECONDARYFNMASK

    override func flagsChanged(with event: NSEvent) {
        let current = event.modifierFlags
        let prev    = previousFlags

        if  current.contains(.command) && !prev.contains(.command) { append("⌘") }
        if  current.contains(.option)  && !prev.contains(.option)  { append("⌥") }
        if  current.contains(.shift)   && !prev.contains(.shift)   { append("⇧") }
        if  current.contains(.control) && !prev.contains(.control) { append("⌃") }

        let curFn  = current.rawValue & fnMask != 0
        let prevFn = prev.rawValue    & fnMask != 0
        if curFn && !prevFn { append("Fn") }

        previousFlags = current
    }

    // Regular keys: append symbol only, ignore modifiers (already captured above)
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 51:                             // Backspace — remove last symbol
            if !displayText.isEmpty {
                // Remove last unicode character (handles multi-char symbols)
                var s = displayText
                s.removeLast()
                onCapture?(s)
            }
            return
        case 117:                            // Forward Delete — clear all
            onClear?()
            return
        case 53:                             // Escape — resign
            window?.makeFirstResponder(nil)
            return
        case 36, 76:                         // Return/Enter — confirm
            window?.makeFirstResponder(nil)
            return
        default: break
        }

        if let sym = specialKey(event.keyCode) {
            append(sym)
        } else if let ch = event.charactersIgnoringModifiers?.uppercased(),
                  let scalar = ch.unicodeScalars.first, scalar.value >= 32 {
            append(ch)
        }
    }

    private func append(_ symbol: String) {
        onCapture?(displayText + symbol)
    }

    private func specialKey(_ code: UInt16) -> String? {
        switch code {
        case 48:  return "⇥"
        case 49:  return "Space"
        case 71:  return "⌧"
        case 96:  return "F5";  case 97:  return "F6";  case 98:  return "F7"
        case 99:  return "F3";  case 100: return "F8";  case 101: return "F9"
        case 103: return "F11"; case 105: return "F13"; case 107: return "F14"
        case 109: return "F10"; case 111: return "F12"; case 113: return "F15"
        case 114: return "⎀"
        case 115: return "↖";  case 116: return "⇞"
        case 117: return "⌦";  case 118: return "F4"
        case 119: return "↘";  case 120: return "F2";  case 121: return "⇟"
        case 122: return "F1"
        case 123: return "←";  case 124: return "→"
        case 125: return "↓";  case 126: return "↑"
        default:  return nil
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)
        NSColor.textBackgroundColor.setFill()
        path.fill()

        (isFocused ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = isFocused ? 2 : 0.5
        path.stroke()

        let str   = displayText.isEmpty ? placeholder : displayText
        let color: NSColor = displayText.isEmpty ? .placeholderTextColor : .labelColor
        let font  = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size  = str.size(withAttributes: attrs)
        str.draw(at: NSPoint(x: 8, y: (bounds.height - size.height) / 2), withAttributes: attrs)
    }
}
