# Biblo — App-Specific Second-Level Actions

The outer command ring pattern generalises to every app in the wheel.
Each app type gets up to 2 (or more) configurable level-2 actions that
appear in the outer ring when that segment is highlighted. The mechanism
varies by app — no single permission model works for all of them.

---

## Pattern

```
Primary wheel segment (hover) → outer ring appears
                                 ↓
                           pick an action
                                 ↓
                        action fires in that app
```

Config in `wheels.json`:

```json
{
  "label": "Cursor",
  "icon": "curlybraces",
  "type": "appWithActions",
  "stickyIndex": 1,
  "actions": [
    { "type": "launchApp", "bundleID": "com.todesktop.230313mzl4w4u92" },
    { "type": "openProject", "path": "~/projects/biblo",   "appBundleID": "com.todesktop.230313mzl4w4u92" },
    { "type": "openProject", "path": "~/projects/website", "appBundleID": "com.todesktop.230313mzl4w4u92" }
  ]
}
```

---

## Terminal Apps (done ✓)

**Mechanism:** `.command` file opened via NSWorkspace. No permissions.

**Config:** `"type": "runInTerminal"` — Settings shows 2 command text fields.

**Apps:** Warp, iTerm2, Terminal.app, Kitty, Alacritty, WezTerm

**Ideas:**
- `cd ~/projects/myapp && npm run dev`
- `ssh prod-server`
- `git log --oneline -20`
- `docker ps`
- `kubectl get pods`

---

## Code Editors (Cursor, VS Code, IntelliJ, Xcode)

**Mechanism:** `open -a "AppName" /path/to/project` via NSWorkspace.
Opens the project in the editor. No permissions required.

**New action type:** `openProject(path: String, appBundleID: String)`

**Config:** Settings shows 2 path fields (with folder picker) for editor segments.

**Ideas:**
- Open `~/projects/biblo` in Cursor
- Open `~/projects/website` in VS Code
- Open recent workspace in IntelliJ
- Open specific `.xcworkspace` in Xcode

**Xcode extras** (future): build/test via `xcodebuild` shell commands wrapped
in `runInTerminal` — same mechanism, no new action type needed.

---

## Browser (Brave, Arc, Safari, Chrome)

**Mechanism:** `NSWorkspace.open(URL)` — opens a URL in the default or
specified browser. No permissions required.

**New action type:** `openURL(url: String)` already exists — reuse it.
For browser segments, Settings shows 2 URL + label fields.

**Ideas:**
- Open `https://github.com/notifications`
- Open `https://linear.app/team`
- Open `http://localhost:3000` (local dev server)
- Open `https://console.aws.amazon.com`

---

## Finder

**Mechanism:** `NSWorkspace.open(URL(fileURLWithPath:))` opens a folder
in Finder. No permissions required.

**New action type:** `openFolder(path: String)` — thin wrapper over `openFile`.
Or reuse `openFile` which already exists.

**Config:** Settings shows 2 path fields (folder picker) for Finder segment.

**Ideas:**
- Open `~/Downloads`
- Open `~/projects`
- Open `~/Desktop`
- Open a specific client folder

---

## Communication Apps (Slack, Mail, Messages)

**Mechanism:** URL schemes — all major comms apps register URL handlers.
No permissions required.

| App     | URL scheme example                          |
|---------|---------------------------------------------|
| Slack   | `slack://open?team=T123&id=C456`           |
| Mail    | `message://` or `mailto:person@co.com`     |
| Linear  | `linear://` or web URL                      |

**New action type:** reuse `openURL` — same as browser.

**Config:** Settings shows 2 URL + label fields for comms segments.

---

## Music / Media

**Mechanism:** `runShell` with `osascript` or Shortcuts.

**Ideas:**
- Play/pause: `osascript -e 'tell application "Music" to playpause'`
- Next track: `osascript -e 'tell application "Music" to next track'`
- Set volume: `osascript -e 'set volume output volume 50'`

**Config:** Settings shows 2 shell command fields (same as terminal, but
for the Music segment).

---

## System / Utilities

**Mechanism:** `runShell` for anything system-level.

**Ideas:**
- Toggle DND: `shortcuts run "Focus: Do Not Disturb"`
- Lock screen: `pmset displaysleepnow`
- Empty trash: `osascript -e 'tell app "Finder" to empty trash'`
- Toggle WiFi: `networksetup -setairportpower en0 off/on`

---

## Implementation Plan

### Phase 1 — Generalise the outer ring (no new action types)

Any segment with `actions.count > 1` already shows the outer ring.
Engineer-savvy users can hand-edit `wheels.json` to add level-2 actions
of any existing type (`openURL`, `openFile`, `runShell`, `runInTerminal`).

No code change needed. Just document the pattern.

### Phase 2 — `openProject` action type

New `BibloAction.openProject(path: String, appBundleID: String)`.
`ActionExecutor` calls `NSWorkspace.open(expandedPath, withApplicationAt: appURL)`.

Settings: editor segments (detected by bundle ID list) show 2 project path
fields with folder-picker buttons instead of command text fields.

**Files:** `Models.swift`, `ActionExecutor.swift`, `SettingsView.swift`, add
`EditorApps.swift` (same pattern as `TerminalApps.swift`).

### Phase 3 — Settings UI per app-type

Generalise `SegmentRow` to detect app category and render appropriate fields:
- Terminal → command text fields (done ✓)
- Editor → project path pickers
- Browser/Comms → URL + label fields
- Generic → raw action list (power-user fallback)

### Phase 4 — App icon in outer ring arcs

Show the action's icon (SF Symbol or derived from path) in each outer arc
instead of just the label text. Makes the outer ring scannable at a glance.

---

## Known Terminals

Tracked in `Sources/Terminal/TerminalApps.swift`:
```
dev.warp.Warp-Stable, com.apple.Terminal, com.googlecode.iterm2,
net.kovidgoyal.kitty, io.alacritty, com.github.wez.wezterm
```

## Known Editors (to add in EditorApps.swift)

```
com.todesktop.230313mzl4w4u92   Cursor
com.microsoft.VSCode             VS Code
com.jetbrains.intellij           IntelliJ IDEA
com.apple.dt.Xcode               Xcode
com.jetbrains.WebStorm           WebStorm
com.jetbrains.PyCharm            PyCharm
com.sublimetext.4                Sublime Text
io.zed.zed                       Zed
```
