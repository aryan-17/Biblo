# Biblo — Engineer Edition Sprint

Living backlog for engineer-focused features. Move items across columns as work progresses.

---

## Done

- [x] **Dynamic segments** — `"dynamicCommand"` on any segment runs a shell command at wheel-open time; each output line becomes a `runShell` action (parallel, 1s timeout)
- [x] **Variable substitution** — `{{clipboard}}`, `{{frontapp.bundle}}`, `{{date}}`, `{{time}}` resolved in any command/URL/path at execution time
- [x] **Shell output capture** — `"captureOutput": true` on `runShell` captures stdout → clipboard + ToastWindow confirmation

---

## Up Next (E2)

- [ ] **SSH host wheel** — parse `~/.ssh/config` at launch, auto-populate segment with hosts as level-2 actions; selecting one opens Terminal and SSHs in
- [ ] **Per-app context wheels** — hotkey summons a different wheel per frontmost app
  - Xcode: build (`⌘B`), test (`⌘U`), clean derived data, open simulator, run
  - VS Code / Cursor: open integrated terminal, format document, git diff, toggle sidebar
  - Terminal: switch tmux session (via `tmux ls` dynamic segment), `cd` to project roots
- [ ] **Multi-step pipelines** — `"type": "pipeline", "steps": [...]`; runs steps in sequence with a progress indicator between steps; last step can be backgrounded
- [ ] **Service health in live segment state** — `"healthURL": "http://localhost:3000/health"` on a segment; icon shows green/red dot based on HTTP reachability
- [ ] **`{{selection}}` token** — resolves to selected text in frontmost app via AXUIElement; requires Accessibility permission (prompt only on first use, graceful fallback to empty string)

---

## Later (E3)

- [ ] **Environment switcher** — action type that swaps a symlink or `.env` file + optionally restarts a named process; useful for dev/staging/prod toggling
- [ ] **Process killer** — `"type": "killProcess", "name": "node"` kills all processes matching name; confirmation toast shows PID count
- [ ] **`LABEL|COMMAND` format in dynamic output** — dynamic command lines parsed as `display label | shell command` so scripts can emit friendly names without encoding them in the command string
- [ ] **`{{item}}` token for dynamic segments** — selected item text from a dynamic segment passed into a template command; enables `git checkout {{item}}` pattern without writing the checkout into the dynamic script

---

## Notes

- `dynamicCommand` output cap: 8 lines (wheel max). Use `head -8` in scripts.
- `{{frontapp.bundle}}` resolves correctly at execution time — `.nonactivatingPanel` keeps the user's app frontmost while the wheel is open.
- `captureOutput` runs async; the wheel closes before capture completes, so the toast appears ~100–500ms after dismissal.
- Per-app wheels (E2) require deciding on config schema: separate `wheels.json` entries with `"appFilter": "com.apple.dt.Xcode"`, or a dedicated `context-wheels.json`.
