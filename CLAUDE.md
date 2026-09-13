# Biblo — Claude & AI Coding Standards

> Loaded every session. All rules apply to every file, every edit.

---

## Project Context

**Biblo** — GTA V-style radial command wheel for macOS.
- `apps/biblo/` — Swift 5.9+ macOS app (Xcode project, generated via xcodegen)
- `apps/web/` — Next.js 16 marketing site (Vercel)
- `releases/appcast.xml` — Sparkle update feed
- `.github/workflows/release.yml` — CI: sign → notarize → DMG → GH Release → appcast

Plan: `PLAN.md`

---

## Non-Negotiable Rules

### Swift (apps/biblo/)

- **Type-check after every change:**
  ```bash
  swiftc -typecheck -target arm64-apple-macosx13.0 \
    -framework AppKit -framework Carbon -framework SwiftUI -framework Combine \
    Sources/**/*.swift
  ```
- **Never recreate the WheelPanel.** It is created once at launch. Recreating per invocation costs ~100ms.
- **Never activate the app.** `NSApp.activate()` is forbidden while the wheel is open. `.nonactivatingPanel` must be preserved.
- **No force-unwrap** in production code paths. Use `guard let` or `if let`.
- **No `DispatchQueue.main.sync`** — deadlock risk. Use `.async` only.
- **Carbon callbacks must be global functions** — closures that capture `self` cannot be C function pointers.
- **Angle math:** `atan2(dx, -dy)` in SwiftUI y-down coords gives clockwise angle from top. Segment 0 centred at 12 o'clock.

### TypeScript / Next.js (apps/web/)

- **Type-check before commit:**
  ```bash
  cd apps/web && npx tsc --noEmit
  ```
- **Build before commit:**
  ```bash
  cd apps/web && npm run build
  ```
- **Do not change env var names in Feedback.tsx.** `FORMSPREE_ID` is intentional — do not rename to `NEXT_PUBLIC_FORMSPREE_ID`.
- **No `ssr: false` in Server Components.** Wrap in a `"use client"` component first (see `HeroWrapper.tsx`).
- **No `node_modules/` edits.** Fix deps at source or patch via `package.json`.

### Git

- Conventional Commits: `feat`, `fix`, `chore`, `ci`, `docs`, `refactor`, `perf`
- Subject ≤ 50 chars, imperative mood, no period
- Scope: `(biblo)` for Swift app, `(web)` for website, `(ci)` for GitHub Actions

---

## Architecture Invariants

These must never be violated:

| # | Invariant | Why |
|---|-----------|-----|
| 1 | WheelPanel created once at launch, never recreated | Latency budget — construction costs ~100ms |
| 2 | `.nonactivatingPanel` always set | Frontmost app must not change when wheel opens |
| 3 | Hotkey handler is a global C function | Carbon callbacks cannot be Swift closures |
| 4 | Max 8 segments | More = muscle memory degrades, flick ambiguity |
| 5 | Dead zone radius = 40pt | Releasing in dead zone = cancel, never fire |
| 6 | Tap threshold = 180ms | < 180ms keydown = repeat last, not browse |
| 7 | Config at `~/.config/biblo/wheels.json` | User-editable, shareable plain JSON |
| 8 | Angle: segment 0 centred at 12 o'clock, clockwise | Muscle memory mapping: up = first segment |

---

## File Map

```
apps/biblo/Sources/
  main.swift                  ← entry point (AppKit, no @main)
  AppDelegate.swift           ← status bar icon + menu
  Models/Models.swift         ← Wheel, Segment, BibloAction (Codable)
  Models/ConfigLoader.swift   ← loads ~/.config/biblo/wheels.json
  Hotkey/HotkeyManager.swift  ← Carbon RegisterEventHotKey (F13)
  Window/WheelPanel.swift     ← NSPanel .nonactivatingPanel
  Window/BackdropWindow.swift ← dim backdrop, ignores mouse
  Views/WheelState.swift      ← ObservableObject
  Views/WheelView.swift       ← Canvas segments + SF Symbol labels
  Actions/ActionExecutor.swift← launchApp, runShell, runShortcut, etc.
  Controller/WheelController.swift ← glues everything

apps/web/
  app/page.tsx                ← composes Hero, Features, Download, Feedback
  components/HeroShader.tsx   ← r3f Canvas + GLSL turbulence shader
  components/HeroWrapper.tsx  ← "use client" boundary for ssr:false
  components/Features.tsx     ← feature cards
  components/Download.tsx     ← DMG download button
  components/Feedback.tsx     ← Formspree form
```

---

## v1 Queue (next)

- [ ] Scroll within segment → cycle actions (level-2), sticky index persist to disk
- [ ] Tap-to-repeat-last
- [ ] SwiftUI Settings scene (preferences window)
- [ ] Sparkle integration
- [ ] Developer ID signing + notarization + first DMG

## v2 Queue

- [ ] Per-app context wheels
- [ ] Payload passing (selected text, Finder files, clipboard)
- [ ] Window management wheel
- [ ] Live segment state (unread counts, battery, DND dot)
- [ ] Invisible-for-experts mode (no UI for flicks < 150ms)

---

## Session Start Checklist

1. Read this file
2. Read `PLAN.md`
3. Check git log: `git log --oneline -10`
4. For Swift changes: confirm type-check passes
5. For web changes: confirm `npx tsc --noEmit` passes
