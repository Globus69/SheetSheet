# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**SheetSheet** is a macOS background utility (no Dock icon) that shows a personal cheat-sheet overlay when the user holds the **Fn key for ≥ 1 second**. Users manage their shortcut cards via a built-in editor inside the overlay — no config file editing.

## Commands

```bash
swift build                  # debug build
swift run                    # run debug binary
swift build -c release       # release build
```

Binary: `.build/debug/SheetSheet` or `.build/release/SheetSheet`.
Open in Xcode: `open Package.swift`.

**First run:** CGEventTap requires Accessibility permission — approve in System Settings → Privacy & Security → Accessibility, then relaunch.

## Architecture

Swift + SwiftUI, macOS 13+, structured as a Swift Package.

```
Sources/SheetSheet/
├── App/
│   ├── SheetSheetApp.swift          # @main, wires AppDelegate
│   └── AppDelegate.swift            # menu bar item, lifecycle, wires all components
├── HotKey/
│   └── FnKeyMonitor.swift           # CGEventTap on flagsChanged; NX_SECONDARYFNMASK long-press → callback
├── Overlay/
│   ├── OverlayWindowController.swift # borderless floating NSPanel with blur; toggle show/hide
│   └── OverlayView.swift            # SwiftUI card list + inline edit/add/delete mode
└── Model/
    ├── ShortcutCard.swift            # Codable struct: title, keys, description
    └── CardStore.swift               # @Observable; persists to ~/Library/Application Support/SheetSheet/cards.json
```

**Key design points:**
- `LSUIElement = YES` in Info.plist → no Dock icon or app switcher entry
- `SMAppService.mainApp.register()` handles login item (macOS 13+ API, no LaunchAgent plist needed)
- Fn key has no standard keycode; detected via `CGEventFlags` bit `0x00800000` (`NX_SECONDARYFNMASK`) in `flagsChanged` events
- `CardStore.cards.didSet` triggers save on every mutation — no explicit save calls needed elsewhere
- The overlay panel uses `.nonactivatingPanel` so it doesn't steal focus from other apps
