# CLAUDE.md — 158 Present Arrow

macOS menu bar app (Swift/AppKit, single file, no Xcode project) for screen-share presenting:
hold **⌥ Option** and move the mouse → an arrow is drawn from where Option was pressed to the cursor; release Option → arrow disappears.

- Source: `Sources/main.swift` · Build: `./build.sh` (→ `build/Present Arrow.app`) · `./build.sh install` copies to `/Applications` and relaunches
- Input is polled (`NSEvent.modifierFlags` / `mouseLocation` @120Hz) → no Accessibility permission needed
- Overlay = one transparent click-through window per screen, level `.screenSaver`
- Only pure Option triggers (⌥+⌘/⌃/⇧ ignored); arrow appears after the mouse moves ≥12pt so ⌥ typing shortcuts don't flash it
- Arrow is a solid fill + drop shadow (a travelling light-trail was tried and removed — Tle didn't like it)
- Limitation: meeting apps' window-only/tab sharing can't see the overlay (separate window). Tle chose docs-only fix (menu hint + README table), not a mirror-window mode
- Settings (UserDefaults, bundle id `com.madebytle.presentarrow`): enabled, color, thickness, Open at Login (SMAppService)

## Public repo + README

- Public: github.com/tlejay/present-arrow (MIT) · Release zip = `./build.sh zip` (universal, ad-hoc signed, not notarized) → `gh release create vX.Y build/Present-Arrow.zip` · README links to `releases/latest/download/Present-Arrow.zip`
- README images (`docs/hero.png`, `docs/demo.gif`, `docs/social-preview.png`) are rendered from the app's real `arrowPath`/`ArrowView` code over a mock slide (renderer lives in session scratchpad, not committed). **Re-render them when the arrow look changes.**
