# Biblo — Engineer Edition Sprint

Living backlog for engineer-focused features. Move items across columns as work progresses.
Full feature spec: `FEATURES.md`

---

## Done

- [x] **Terminal command launcher** — terminal segments show outer ring with up to 2 configurable commands; opens new tab via `.command` file (no permissions). `zsh -il` loads aliases/PATH. Settings shows command text fields. Arrow keys (←/→) cycle outer ring.
- [x] **Outer command ring UI** — second arc ring outside primary wheel for any segment with level-2 actions. Both options visible simultaneously. Cursor moves outward to select; haptic feedback on crossing.
- [x] **`openProject` action type** — editor segments (Cursor, VS Code, IntelliJ, Xcode, WebStorm, PyCharm, Zed…) show 2 project path pickers with folder picker buttons in Settings. Uses CLI (`cursor`, `idea`, `code`) with bare path so existing windows are focused rather than new ones opened. JetBrains IDEs use the app bundle binary for IPC-based window reuse. No permissions required.
- [x] **Editor segment detection** — `EditorApps.swift` with known bundle IDs + CLI path lookup per editor.

---

## Up Next (E2)

- [ ] **Browser/comms URL actions** — browser and comms segments (Arc, Brave, Safari, Slack, Linear…) show 2 URL + label fields in Settings; reuses existing `openURL` action. Detect by bundle ID via new `BrowserApps.swift`. No new action type.
- [ ] **SSH host wheel** — parse `~/.ssh/config` at launch, auto-populate segment with hosts as level-2 `runInTerminal` actions; selecting one SSHs in.
- [ ] **Per-app context wheels** — different wheel per frontmost app (Xcode, VS Code, Finder).
- [ ] **Service health in live segment state** — `"healthURL"` on a segment; icon shows green/red dot based on HTTP reachability.

---

## Later (E3)

- [ ] **Settings UI per app-type** — `SegmentRow` detects app category (terminal/editor/browser/comms) and renders appropriate config fields.
- [ ] **App icon in outer ring arcs** — show path-derived or SF Symbol icon in each outer arc.
- [ ] **Environment switcher** — swap symlink or `.env` file + optionally restart a process.
- [ ] **Process killer** — `"type": "killProcess", "name": "node"` kills matching processes.
- [ ] **More than 2 outer ring actions** — raise limit when there's a use case.
- [ ] **Multi-step pipelines** — `"type": "pipeline", "steps": [...]` with progress indicator.

---

## Notes

- **Terminal detection:** `TerminalApps.swift`. **Editor detection:** `EditorApps.swift`. **Browser (planned):** `BrowserApps.swift`.
- **Editor CLI priority:** CLI tool → JetBrains app binary → NSWorkspace fallback.
- **Why CLI for editors:** `NSWorkspace.open` sends Apple Events; JVM apps (IntelliJ) ignore "is already open" logic. CLI uses each editor's own IPC to check before creating a new window.
- **No permissions:** all current features use NSWorkspace or CLI subprocess — zero Automation/Accessibility required.
- **Outer ring geometry:** appears at cursor radius > 160pt from wheel centre.
- **Hand-editing `wheels.json`:** any segment with `actions.count > 1` shows the outer ring automatically.
