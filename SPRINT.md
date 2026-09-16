# Biblo — Engineer Edition Sprint

Living backlog for engineer-focused features. Move items across columns as work progresses.

---

## Done

- [x] **Terminal command launcher** — any terminal segment (Warp, iTerm2, Terminal.app etc.) shows a second outer ring with up to 2 configurable commands; selecting one opens a new tab running that command. No permissions required — uses a temp `.command` file opened via NSWorkspace. Commands configurable from Settings panel. Arrow keys (←/→) cycle outer ring; cursor in outer arc selects visually.
- [x] **Outer command ring UI** — when a terminal segment is highlighted, an outer arc ring appears outside the primary wheel showing both commands simultaneously. Moving cursor outward selects one; haptic feedback on selection.

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
- [ ] **More terminal commands** — currently max 2; raise limit when there's a use case
- [ ] **`LABEL|COMMAND` format in dynamic output** — dynamic command lines parsed as `display label | shell command` so scripts can emit friendly names

---

## Notes

- Terminal segments detected by bundle ID against a known list (`TerminalApps.swift`). Add new terminals there.
- Commands run in `zsh -il` (interactive login shell) — aliases, functions, and PATH from `.zshrc` all work.
- Temp `.command` files auto-delete via `trap 'rm -f' EXIT` when the command finishes.
- Outer ring appears at cursor radius > 160pt from wheel center. Move cursor ~2 inches outward to enter it.
- Per-app wheels (E2) require deciding on config schema: separate `wheels.json` entries with `"appFilter": "com.apple.dt.Xcode"`, or a dedicated `context-wheels.json`.
