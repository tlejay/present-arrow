# CLAUDE.md — 158 Present Arrow

macOS menu bar app (Swift/AppKit, single file, no Xcode project) for screen-share presenting:
hold **⌥ Option** and move the mouse → an arrow is drawn from where Option was pressed to the cursor; release Option → arrow disappears.

- Source: `Sources/main.swift` · Build: `./build.sh` (→ `build/Present Arrow.app`) · `./build.sh install` copies to `/Applications` and relaunches
- Input is polled (`NSEvent.modifierFlags` / `mouseLocation` @120Hz) → no Accessibility permission needed
- Overlay = one transparent click-through window per screen, level `.screenSaver`
- Only pure Option triggers (⌥+⌘/⌃/⇧ ignored); arrow appears after the mouse moves ≥12pt so ⌥ typing shortcuts don't flash it
- Settings (UserDefaults, bundle id `com.madebytle.presentarrow`): enabled, color, thickness, Open at Login (SMAppService)
