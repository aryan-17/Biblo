# Biblo — a GTA V weapon-wheel launcher for macOS

A hold-to-open radial command wheel. Flick a direction, release, something happens.
Launch apps, run shortcuts, snap windows, act on whatever you have selected.

---

## 1. Design principles

These are the mechanics that make the GTA weapon wheel work. Copying the visual
without these produces a pretty menu nobody uses.

| # | Principle | Why it matters | How it maps to macOS |
|---|-----------|----------------|----------------------|
| 1 | Hold to open, release to commit | The interaction has a definite start and end; no stale UI, no dismiss step | Global hotkey with key-down / key-up tracking |
| 2 | Direction is the address | Hands remember "up-left" far better than "third item down" | Angle from cursor origin selects a segment |
| 3 | Exactly two levels | Depth without a menu tree | Direction picks category, scroll picks item |
| 4 | Sticky selection | The wheel learns you; last pick becomes that segment's default | Persist per-segment default in config |
| 5 | Center is cancel | A safe neutral you can always retreat to | Dead zone radius ~40pt, releasing there is a no-op |
| 6 | Tap vs. hold, same key | Tap = repeat last action, hold = browse | Distinguish by press duration (<180ms = tap) |
| 7 | Time dilation | The mode feels safe because the world pauses | Dim + blur everything behind the wheel |

**The one to protect hardest:** #2 combined with #5. That pairing is what lets an
expert use the wheel without looking at it. Every feature decision should be checked
against "does this still work with my eyes closed?"

---

## 2. Architecture

### 2.1 Stack

- **Swift 5.9+**, minimum target macOS 13 Ventura
- **SwiftUI** for wheel rendering (`Canvas`, or rotated `Shape` paths per segment)
- **AppKit** for window plumbing, hotkeys, and event handling
- **Carbon `RegisterEventHotKey`** for the global hotkey (still fully supported, no permissions needed)
- **Sparkle** for auto-updates
- No other third-party dependencies in the MVP

### 2.2 The overlay window

This is the part that's easy to get wrong and hard to retrofit.

```
NSPanel
  .styleMask         = [.borderless, .nonactivatingPanel]
  .level             = .floating (or .statusBar for above-fullscreen)
  .isOpaque          = false
  .backgroundColor   = .clear
  .collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
  .hidesOnDeactivate = false
```

Plus `LSUIElement = true` in `Info.plist` so there's no Dock icon or menu bar.

Two rules:

- **The panel must never activate the app.** If the frontmost application changes when
  the wheel opens, every context-aware and payload-aware feature dies, because you've
  lost the thing you were trying to act on.
- **Create the panel once at launch and keep it alive, hidden.** Constructing it per
  invocation costs ~100ms of layout, which is the entire latency budget.

### 2.3 Input

Three input paths, all live simultaneously:

| Path | Behaviour |
|------|-----------|
| Mouse / trackpad | Wheel appears centered on cursor; angle from origin highlights a segment |
| Number keys 1–8 | Jump straight to a segment — fastest for keyboard users, and it's what GTA does on PC |
| Scroll / arrow keys | Cycle items *within* the highlighted segment (level-2 only) |

Event capture while the panel is open: a local `NSEvent` monitor is enough for scroll
and mouse-moved. Key-up for the hotkey itself comes from the Carbon handler.

### 2.4 Segment data model

```swift
struct Wheel: Codable {
    var id: String
    var hotkey: HotkeyConfig
    var segments: [Segment]   // max 8
}

struct Segment: Codable {
    var label: String
    var icon: String           // SF Symbol name or app bundle ID for auto-icon
    var type: SegmentType
    var stickyIndex: Int       // last-used action index (persisted)
    var actions: [Action]      // level 1 = 1 action, level 2 = multiple
}

enum SegmentType: String, Codable {
    case appOnly               // launchApp, level 1
    case actionOnly            // any action, level 1
    case appWithActions        // launchApp + scrollable actions, level 2
}
```

### 2.5 Action layer

Define a small closed set of action types. Everything else becomes configuration
rather than code.

```swift
enum Action: Codable {
    case launchApp(bundleID: String)
    case runShortcut(name: String)        // shells out to `shortcuts run`
    case runShell(command: String)
    case openURL(url: String)
    case sendKeystroke(keyCombo: String)
    case runAppleScript(source: String)
    case openFile(path: String)
}
```

Wiring `runShortcut` in early is the highest-leverage decision in the whole project.
Shortcuts.app already integrates with hundreds of apps and system features, so it
answers "how do I support every app on the Mac" for roughly a day of work.

### 2.6 Config

Plain-text JSON at `~/.config/biblo/wheels.json`, with a GUI editor layered
on top later. Hand-editable text means users will share configs, which is free
marketing and free feature discovery.

```json
{
  "wheels": [
    {
      "id": "main",
      "hotkey": { "key": "F13", "modifiers": [] },
      "segments": [
        {
          "label": "Terminal",
          "icon": "terminal",
          "type": "appWithActions",
          "stickyIndex": 0,
          "actions": [
            { "type": "runShell", "command": "open -a Terminal" },
            { "type": "runShell", "command": "bash ~/scripts/deploy.sh" }
          ]
        }
      ]
    }
  ]
}
```

### 2.7 Control panel

Native SwiftUI `Settings` scene, accessible via NSStatusItem in the menu bar.

Screens:
1. **Wheel overview** — 8 segment slots, drag to reorder, click to edit
2. **Segment editor** — label, icon picker (SF Symbols + app picker), type selector
3. **Action builder** — type dropdown + type-specific fields (shell editor, shortcut picker, URL field, key recorder, AppleScript editor, file picker)
4. **Hotkey** — key recorder, conflict detection
5. **About** — version, Sparkle update check

### 2.8 Distribution

Running arbitrary shell commands puts you outside the App Store sandbox. Plan for:

- Developer ID signing + notarization
- Direct `.dmg` download from the website
- Sparkle for auto-updates
- GitHub Actions CI on tag push (`v*`)

---

## 3. Feature roadmap

Ordered by how much each one differentiates the product.

### Tier 1 — the reason to build this

**Context-aware wheels.** The same hotkey summons a different wheel depending on the
frontmost app. In Xcode: build, test, git. In Figma: export, plugins, components. In
Finder: move-to-folder destinations. This is the entire gap between "another launcher"
and something people can't work without. Every other item on this list is a nice touch
by comparison.

**Payload awareness.** Whatever is currently selected — Finder files, highlighted text,
clipboard contents — becomes an implicit argument to the action. Flick right, release,
the selected file uploads. Flick down, the highlighted text goes through a translation
shortcut. This turns a launcher into a verb dispatcher, and it's the reason the
non-activating panel matters so much.

**Window-management wheel.** Direction-to-meaning is not decorative here, it's literally
correct: flick left snaps left half, up-left snaps top-left quarter, up maximizes. The
best possible demo of why the radial metaphor deserves to exist.

### Tier 2 — polish that people notice

**Invisible-for-experts rendering.** Draw nothing for the first ~150ms. If the user
flicks and releases inside that window, the action fires and no UI ever appears. If they
hesitate, the wheel fades in with labels. One binding serves both the first-timer and the
person who's done it four thousand times.

**Live segment state.** Ammo count is the model to copy. Unread count on the mail
segment, battery on system, a dot when Do Not Disturb is on. The wheel becomes glanceable
status rather than just a menu.

**Haptics and audio.** `NSHapticFeedbackManager` on segment crossing gives a physical
detent on trackpads. Add a short click sound. Cheap to build, wildly satisfying, very GTA.

**Multiple wheels on multiple keys.** F13 = apps, F14 = windows, F15 = media. Cheaper
than nesting, faster to reach, and it sidesteps the eight-segment limit honestly.

### Tier 3 — later

- Recent-items segment that populates itself from usage
- Time-of-day wheels (morning wheel vs. evening wheel)
- Multi-monitor origin rules
- Config sharing / import from a URL

---

## 4. Build order

### Phase 0 — Repo scaffold
- [ ] Create `apps/web/` Next.js 14 site
- [ ] Create `apps/biblo/` Xcode project
- [ ] Add root `.gitignore`

### MVP — prove the core works
- [ ] `LSUIElement` app skeleton, NSStatusItem menu bar icon
- [ ] Persistent hidden `NSPanel` created at launch
- [ ] Carbon global hotkey with key-down and key-up
- [ ] Wheel rendering: 8 segments, dead center, highlight on hover
- [ ] Angle-from-cursor hit testing
- [ ] Keys 1–8 selection
- [ ] `launchApp` + `runShell` actions
- [ ] Dimmed / blurred backdrop
- [ ] Hand-edited JSON config at `~/.config/biblo/wheels.json`

**Exit criterion:** keydown → wheel visible in under one frame (16ms), and the frontmost
app does not change when the wheel opens.

### v1 — make it useful
- [ ] All action types (`runShortcut`, `openURL`, `sendKeystroke`, `runAppleScript`, `openFile`)
- [ ] Level-2: scroll within hovered segment cycles actions, sticky index persisted
- [ ] Tap-to-repeat-last (<180ms)
- [ ] Full control panel (SwiftUI Settings)
- [ ] Sparkle integration
- [ ] Onboarding flow for permissions
- [ ] Haptics on segment crossing
- [ ] Signing, notarization, `.dmg`

### v2 — make it indispensable
- [ ] Per-app context wheels
- [ ] Payload passing (selection, clipboard, Finder files)
- [ ] Window-management wheel
- [ ] Live segment state
- [ ] Invisible-for-experts mode
- [ ] Multiple wheels on multiple hotkeys
- [ ] Config sharing

---

## 5. Risks and things that will bite

**Latency is the entire product.** If there is any perceptible gap between keydown and
the wheel appearing, people stop trusting it and go back to Spotlight. Pre-warm the
panel, pre-render segment geometry, pre-load icons at launch. Measure with signposts,
not vibes.

**Do not go past eight segments.** The moment you allow twelve, flicks become ambiguous
and the muscle-memory advantage — the whole point — evaporates. If a user needs more
actions, they need a second wheel, not a denser one.

**Permission prompts are the main drop-off point.** Accessibility (for `sendKeystroke`
and window management) and Automation (for AppleScript) both throw scary system dialogs.
Explain each one in your own UI *before* triggering it, and never ask for a permission
until the feature that needs it is actually used.

**Full-screen apps and Spaces.** Getting the panel to appear above a full-screen app
needs the right `collectionBehavior` and possibly `.statusBar` window level. Test early;
it's annoying to discover late.

**Secure input mode.** When a password field has focus, macOS blocks event taps entirely.
Detect it and fail gracefully rather than appearing broken.

**Don't rebuild Raycast.** The moment you add a text field, you've lost. The radial
metaphor is the differentiator; search is somebody else's product.

---

## 6. Open questions

- Default hotkey — F13 is unclaimed on most keyboards but missing on laptops. Hold-right-⌘
  is elegant but requires a `CGEventTap` and Accessibility permission from day one.
- Where does the wheel open: at the cursor, at screen center, or at the last-used position?
  Cursor is fastest for mouse users, center is more predictable for keyboard users.
- Icons: pull from app bundles automatically, or SF Symbols, or user-supplied?
- Free with a paid tier, or one-time purchase? Context wheels are the obvious paid feature.
