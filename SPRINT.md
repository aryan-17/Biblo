# Biblo — Engineer Edition Sprint

Living backlog for engineer-focused features. Move items across columns as work progresses.
Full feature spec: `FEATURES.md`

---

## Done

- [x] **Terminal command launcher** — terminal segments (Warp, iTerm2, etc.) show an outer ring with up to 2 configurable commands; selecting one opens a new tab running that command. No permissions required — temp `.command` file via NSWorkspace. `zsh -il` so aliases and PATH work. Settings panel shows command text fields for terminal segments. Arrow keys (←/→) cycle outer ring.
- [x] **Outer command ring UI** — second arc ring appears outside primary wheel when a terminal segment is highlighted. Both commands visible simultaneously. Cursor moves outward to select; haptic feedback on crossing.

---

## Up Next (E2)

- [ ] **`openProject` action type** — `BibloAction.openProject(path:appBundleID:)` opens a folder/workspace in the target editor via `NSWorkspace.open`. Settings shows project path pickers for editor segments (Cursor, VS Code, IntelliJ, Xcode). No permissions. See `FEATURES.md § Phase 2`.
- [ ] **Editor segment detection** — add `EditorApps.swift` (same pattern as `TerminalApps.swift`); Settings auto-shows project path fields for known editors.
- [ ] **Browser/comms URL actions** — browser and comms segments show 2 URL + label fields in Settings; reuses existing `openURL` action. No new action type needed.
- [ ] **SSH host wheel** — parse `~/.ssh/config` at launch, auto-populate segment with hosts; selecting one opens terminal + SSHs in.
- [ ] **Per-app context wheels** — different wheel per frontmost app (Xcode, VS Code, Finder). See `FEATURES.md` for app-specific ideas.
- [ ] **Service health in live segment state** — `"healthURL"` on a segment; icon shows green/red dot based on HTTP reachability.

---

## Later (E3)

- [ ] **Settings UI per app-type** — `SegmentRow` detects app category (terminal/editor/browser/comms) and renders appropriate config fields instead of generic action list. See `FEATURES.md § Phase 3`.
- [ ] **App icon in outer ring arcs** — show SF Symbol or path-derived icon in each outer arc. See `FEATURES.md § Phase 4`.
- [ ] **Environment switcher** — swap symlink or `.env` file + optionally restart a process; dev/staging/prod toggling.
- [ ] **Process killer** — `"type": "killProcess", "name": "node"` kills matching processes.
- [ ] **More than 2 outer ring actions** — raise limit when there's a use case (currently max 2 per segment).
- [ ] **Multi-step pipelines** — `"type": "pipeline", "steps": [...]` with progress indicator.

---

## Notes

- **Terminal detection:** bundle ID checked against `TerminalApps.swift`. Add new terminals there.
- **Editor detection (planned):** same pattern via `EditorApps.swift`.
- **No permissions:** terminal launcher uses `.command` file + NSWorkspace — zero Automation/Accessibility required.
- **Shell:** commands run in `zsh -il` (interactive login shell) — aliases, functions, PATH from `.zshrc` all load.
- **Outer ring geometry:** appears at cursor radius > 160pt. User moves cursor ~2 inches outward to enter it.
- **Hand-editing `wheels.json`:** any segment with `actions.count > 1` already shows the outer ring. Power users can add level-2 actions of any existing type without waiting for Settings UI support.
