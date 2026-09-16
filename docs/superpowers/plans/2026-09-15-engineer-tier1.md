# Engineer Tier-1 Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three power-user features for engineers: (1) dynamic segment population from shell output, (2) variable substitution (`{{token}}`) in any command string, (3) shell output capture to clipboard with toast confirmation.

**Architecture:** `VariableResolver` resolves `{{tokens}}` in command strings at execution time. `Segment.dynamicCommand` populates a segment's action list by running a shell command at wheel-open time (parallel, 1-second per-command timeout, blocks wheel display). `BibloAction.runShell` gains a `captureOutput: Bool` flag — when true, stdout is captured asynchronously, written to clipboard, and a `ToastWindow` confirmation appears.

**Tech Stack:** Swift 5.9+, AppKit, SwiftUI, Foundation, DispatchGroup

**Spec:** Tier-1 engineer features from 2026-09-15 brainstorm session.

## Global Constraints

- Type-check after every task (run from `apps/biblo/`):
  ```bash
  cd apps/biblo && swiftc -typecheck -target arm64-apple-macosx13.0 \
    -framework AppKit -framework Carbon -framework SwiftUI -framework Combine \
    $(find Sources -name "*.swift" | tr '\n' ' ')
  ```
- No force-unwrap in production paths — use `guard let` or `if let`.
- No `DispatchQueue.main.sync` — deadlock risk. Use `.async` only.
- WheelPanel created once at launch — never recreate.
- `NSApp.activate()` forbidden while wheel is open.

---

## File Map

| File | Status | Responsibility |
|------|--------|----------------|
| `PLAN.md` | Modify | Add engineer features roadmap |
| `Sources/Models/Models.swift` | Modify | `Segment.dynamicCommand`; `runShell(captureOutput:)` |
| `Sources/Actions/VariableResolver.swift` | **Create** | Resolve `{{clipboard}}`, `{{frontapp.bundle}}`, `{{date}}`, `{{time}}` |
| `Sources/Actions/ActionExecutor.swift` | Modify | Apply resolver to all string args; async capture for `captureOutput` |
| `Sources/Views/WheelState.swift` | Modify | Add `dynamicActions: [Int: [BibloAction]]` |
| `Sources/Views/WheelView.swift` | Modify | Use `dynamicActions` for action count + sub-labels |
| `Sources/Controller/WheelController.swift` | Modify | `populateDynamicSegments()`; `effectiveActions(for:)`; `fireAction(_:)`; `ToastWindow` hold |
| `Sources/Window/ToastWindow.swift` | **Create** | Floating auto-dismiss confirmation panel |

---

### Task 0: Update PLAN.md with all engineer features

**Files:**
- Modify: `PLAN.md` (add new "Engineer Edition" roadmap section after existing Tier 3)

- [ ] **Step 1: Open PLAN.md and add engineer features section**

Add the following block after the existing "Tier 3 — later" section in section 3:

```markdown
### Engineer Edition — power-user features

**Tier E1 — Tier 1 (in progress)**

**Dynamic segments from shell output.** A segment with `dynamicCommand` runs a shell
command at wheel-open time; each output line becomes a `runShell` action. Engineers
configure `git branch | head -8` for a branch-switcher, `docker ps --format '{{.Names}}'`
for a container wheel, etc. Commands run in parallel with a 1-second timeout.

**Variable substitution in commands.** Any command string can embed `{{clipboard}}`,
`{{frontapp.bundle}}`, `{{date}}`, `{{time}}` — resolved at execution time.
Example: `open "https://jira.co/browse/{{clipboard}}"` opens the ticket whose key
was copied. Frontmost app does not change while the wheel is open (nonactivatingPanel),
so `{{frontapp.bundle}}` resolves to the user's working app.

**Shell output capture.** `"captureOutput": true` on a `runShell` action captures
stdout to the clipboard and shows a toast confirmation. Engineers use this to run
`git rev-parse HEAD`, `pbcopy` alternatives, script output inspection.

**Tier E2 — next**

- [ ] SSH host wheel — parse `~/.ssh/config` for hosts, level-2 actions open terminal + SSH
- [ ] Per-app context wheels — Xcode: build/test/clean/run; VSCode: terminal/format/diff
- [ ] Multi-step pipelines — `"type": "pipeline", "steps": [...]` with progress indicator
- [ ] Service health in live segment state — ping URL, show green/red dot
- [ ] `{{selection}}` token (requires Accessibility permission — ask only on first use)

**Tier E3 — later**

- [ ] Environment switcher (swap symlinks + restart service)
- [ ] Process killer by name (`"type": "killProcess", "name": "node"`)
- [ ] Git branch switcher via dynamic segment + `git checkout {{item}}`
- [ ] `LABEL|COMMAND` format in dynamic command output for custom display labels
```

- [ ] **Step 2: Verify PLAN.md renders correctly**

Open `PLAN.md` and confirm the new section appears after Tier 3. No trailing whitespace issues.

- [ ] **Step 3: Commit**

```bash
git add PLAN.md
git commit -m "docs(biblo): add engineer edition features to PLAN.md"
```

---

### Task 1: Extend Models

**Files:**
- Modify: `apps/biblo/Sources/Models/Models.swift`

**Interfaces:**
- Produces: `Segment.dynamicCommand: String?`; `BibloAction.runShell(command: String, captureOutput: Bool)`
- All downstream tasks depend on these types.

- [ ] **Step 1: Add `dynamicCommand` to `Segment`**

The struct uses synthesized Codable, so an optional property decodes with `decodeIfPresent` — backward-compatible with existing JSON that omits the field.

Replace the `Segment` struct:

```swift
struct Segment: Codable {
    var label: String
    var icon: String          // SF Symbol name
    var type: SegmentType
    var stickyIndex: Int
    var actions: [BibloAction]
    var dynamicCommand: String?  // if set, populated at wheel-open time; overrides actions
}
```

- [ ] **Step 2: Add `captureOutput` to `BibloAction.runShell`**

Change:
```swift
case runShell(command: String)
```
to:
```swift
case runShell(command: String, captureOutput: Bool)
```

Add `captureOutput` to `CodingKeys`:
```swift
private enum CodingKeys: String, CodingKey {
    case type, bundleID, command, name, url, keyCombo, source, path, captureOutput
}
```

- [ ] **Step 3: Update `init(from decoder:)` for `runShell`**

Change:
```swift
case "runShell":    self = .runShell(command: try c.decode(String.self, forKey: .command))
```
to:
```swift
case "runShell":
    let cmd     = try c.decode(String.self, forKey: .command)
    let capture = (try? c.decode(Bool.self, forKey: .captureOutput)) ?? false
    self = .runShell(command: cmd, captureOutput: capture)
```

- [ ] **Step 4: Update `encode(to:)` for `runShell`**

Change:
```swift
case .runShell(let v):     try c.encode("runShell", forKey: .type);     try c.encode(v, forKey: .command)
```
to:
```swift
case .runShell(let cmd, let capture):
    try c.encode("runShell", forKey: .type)
    try c.encode(cmd, forKey: .command)
    if capture { try c.encode(true, forKey: .captureOutput) }
```

- [ ] **Step 5: Update `displayLabel` for `runShell`**

Change:
```swift
case .runShell(let cmd):     return String(cmd.prefix(24))
```
to:
```swift
case .runShell(let cmd, _):  return String(cmd.prefix(24))
```

- [ ] **Step 6: Type-check**

```bash
cd apps/biblo && swiftc -typecheck -target arm64-apple-macosx13.0 \
  -framework AppKit -framework Carbon -framework SwiftUI -framework Combine \
  $(find Sources -name "*.swift" | tr '\n' ' ')
```

Expected: 0 errors. If `"Pattern cannot match values of type 'BibloAction'"` — a call site still uses the old single-arg pattern. Grep for `.runShell(let` to find them.

- [ ] **Step 7: Commit**

```bash
git add apps/biblo/Sources/Models/Models.swift
git commit -m "feat(biblo): extend models for dynamic segments and captureOutput"
```

---

### Task 2: VariableResolver

**Files:**
- Create: `apps/biblo/Sources/Actions/VariableResolver.swift`

**Interfaces:**
- Produces: `VariableResolver.resolve(_ template: String) -> String`
- Consumed by: `ActionExecutor` (Task 3) and `WheelController.populateDynamicSegments()` (Task 4)

**Tokens:**
| Token | Value |
|-------|-------|
| `{{clipboard}}` | `NSPasteboard.general.string(forType: .string) ?? ""` |
| `{{frontapp.bundle}}` | `NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""` |
| `{{date}}` | `yyyy-MM-dd` formatted current date |
| `{{time}}` | `HH:mm` formatted current time |

Note: `{{frontapp.bundle}}` resolves to the user's working app at execution time because `.nonactivatingPanel` means Biblo never becomes frontmost while the wheel is open.

- [ ] **Step 1: Create `VariableResolver.swift`**

```swift
import AppKit
import Foundation

/// Replaces {{tokens}} in template strings with live system values.
enum VariableResolver {

    /// Resolves all supported {{tokens}} in `template`.
    static func resolve(_ template: String) -> String {
        guard template.contains("{{") else { return template }   // fast path
        var result = template
        result = result.replacingOccurrences(of: "{{clipboard}}",      with: clipboard())
        result = result.replacingOccurrences(of: "{{frontapp.bundle}}", with: frontAppBundle())
        result = result.replacingOccurrences(of: "{{date}}",            with: isoDate())
        result = result.replacingOccurrences(of: "{{time}}",            with: currentTime())
        return result
    }

    // ── Token providers ───────────────────────────────────────────────────────

    private static func clipboard() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    private static func frontAppBundle() -> String {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
    }

    private static func isoDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func currentTime() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }
}
```

- [ ] **Step 2: Type-check**

```bash
cd apps/biblo && swiftc -typecheck -target arm64-apple-macosx13.0 \
  -framework AppKit -framework Carbon -framework SwiftUI -framework Combine \
  $(find Sources -name "*.swift" | tr '\n' ' ')
```

Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add apps/biblo/Sources/Actions/VariableResolver.swift
git commit -m "feat(biblo): VariableResolver — {{clipboard}}, {{frontapp.bundle}}, {{date}}, {{time}}"
```

---

### Task 3: Wire VariableResolver + captureOutput into ActionExecutor

**Files:**
- Modify: `apps/biblo/Sources/Actions/ActionExecutor.swift`

**Interfaces:**
- Consumes: `VariableResolver.resolve(_:)` from Task 2; `BibloAction.runShell(command:captureOutput:)` from Task 1
- Produces: `ActionExecutor.execute(_ action: BibloAction, onCapture: ((String) -> Void)? = nil)` — backward-compatible, existing call sites unchanged

**Behavior change:** All string-bearing actions resolve `{{tokens}}` before use. `runShell` with `captureOutput: true` runs async, writes stdout to clipboard on main thread, then calls `onCapture(stdout)`.

- [ ] **Step 1: Rewrite `ActionExecutor.swift`**

Replace the entire file with:

```swift
import AppKit
import Foundation

enum ActionExecutor {

    /// Execute `action`, resolving {{tokens}} in all string arguments.
    /// For `runShell(captureOutput: true)`: runs async; on completion writes
    /// stdout to clipboard (if non-empty) and calls `onCapture(stdout)`.
    /// For all other actions: synchronous fire-and-forget; `onCapture("")` called immediately.
    static func execute(_ action: BibloAction, onCapture: ((String) -> Void)? = nil) {
        switch action {

        case .launchApp(let bundleID):
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                NSLog("Biblo: app not found — \(bundleID)")
                onCapture?("")
                return
            }
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            onCapture?("")

        case .runShell(let command, let captureOutput):
            let resolved = VariableResolver.resolve(command)
            if captureOutput {
                captureShell(resolved, onCapture: onCapture)
            } else {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/zsh")
                task.arguments     = ["-lc", resolved]
                try? task.run()
                onCapture?("")
            }

        case .runShortcut(let name):
            let resolved = VariableResolver.resolve(name)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            task.arguments     = ["run", resolved]
            try? task.run()
            onCapture?("")

        case .openURL(let urlString):
            let resolved = VariableResolver.resolve(urlString)
            guard let url = URL(string: resolved) else {
                NSLog("Biblo: invalid URL — \(resolved)")
                onCapture?("")
                return
            }
            NSWorkspace.shared.open(url)
            onCapture?("")

        case .openFile(let path):
            let resolved = VariableResolver.resolve(path)
            NSWorkspace.shared.open(URL(fileURLWithPath: resolved))
            onCapture?("")

        case .sendKeystroke(let combo):
            NSLog("Biblo: sendKeystroke not yet implemented — \(combo)")
            onCapture?("")

        case .runAppleScript(let source):
            let resolved = VariableResolver.resolve(source)
            guard let script = NSAppleScript(source: resolved) else {
                onCapture?("")
                return
            }
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let err = error { NSLog("Biblo: AppleScript error — \(err)") }
            onCapture?("")
        }
    }

    // ── Private ───────────────────────────────────────────────────────────────

    /// Runs `command` in /bin/zsh, captures stdout, writes to clipboard, calls completion on main.
    private static func captureShell(_ command: String, onCapture: ((String) -> Void)?) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments     = ["-lc", command]
            let outPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError  = Pipe()   // discard stderr

            guard (try? task.run()) != nil else {
                DispatchQueue.main.async { onCapture?("") }
                return
            }
            task.waitUntilExit()

            let data   = outPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            DispatchQueue.main.async {
                if !output.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                }
                onCapture?(output)
            }
        }
    }
}
```

- [ ] **Step 2: Type-check**

```bash
cd apps/biblo && swiftc -typecheck -target arm64-apple-macosx13.0 \
  -framework AppKit -framework Carbon -framework SwiftUI -framework Combine \
  $(find Sources -name "*.swift" | tr '\n' ' ')
```

Expected: 0 errors. Common error: `WheelController.swift` still calls `ActionExecutor.execute(action)` — that's fine, `onCapture` has a default of `nil`. The error would only appear if the call somehow breaks the label.

- [ ] **Step 3: Commit**

```bash
git add apps/biblo/Sources/Actions/ActionExecutor.swift
git commit -m "feat(biblo): apply VariableResolver to all actions; captureOutput async shell capture"
```

---

### Task 4: Dynamic segments

**Files:**
- Modify: `apps/biblo/Sources/Views/WheelState.swift`
- Modify: `apps/biblo/Sources/Views/WheelView.swift`
- Modify: `apps/biblo/Sources/Controller/WheelController.swift`

**Interfaces:**
- Consumes: `Segment.dynamicCommand` from Task 1; `VariableResolver.resolve(_:)` from Task 2
- Produces: `WheelState.dynamicActions: [Int: [BibloAction]]`; `WheelController.effectiveActions(for:) -> [BibloAction]`

**Dynamic command output format:** Each non-empty line of stdout becomes a `runShell(command: line, captureOutput: false)` action. Display label = first 24 chars of command. `ponytail: LABEL|CMD format deferred — add when first user requests custom labels`

**Timing:** `populateDynamicSegments()` is called in `handleKeyDown()` *before* showing the wheel. All dynamic commands run in parallel via `DispatchGroup` with a 1-second per-command timeout (the group.wait() blocks main thread briefly — acceptable since the wheel hasn't appeared yet).

- [ ] **Step 1: Add `dynamicActions` to `WheelState.swift`**

Replace `WheelState.swift` with:

```swift
import Foundation
import Combine

/// Shared observable state driving WheelView.
final class WheelState: ObservableObject {
    @Published var wheel: Wheel?
    @Published var highlightedIndex: Int?
    @Published var actionIndices: [Int: Int] = [:]
    @Published var wheelOrigin: CGPoint = .zero
    /// Populated at wheel-open time for segments with dynamicCommand.
    /// Overrides the segment's static `actions` array for display and execution.
    @Published var dynamicActions: [Int: [BibloAction]] = [:]
}
```

- [ ] **Step 2: Update `WheelView.swift` to use dynamic actions**

In the `ForEach` block (around line 90), replace:

```swift
let actionIdx = min(
    state.actionIndices[i] ?? seg.stickyIndex,
    seg.actions.count - 1
)

VStack(spacing: 3) {
    SegmentIconView(segment: seg, highlighted: highlighted)

    Text(seg.label)
        .font(.system(size: 11, weight: highlighted ? .semibold : .regular))
        .foregroundStyle(highlighted ? Color.white : Color.white.opacity(0.38))
        .fixedSize()

    // Sub-label for level-2 segments
    if seg.actions.count > 1 {
        Text(seg.actions[actionIdx].displayLabel)
            .font(.system(size: 9))
            .foregroundStyle(
                highlighted
                    ? Color(red: 0.7, green: 0.65, blue: 1.0).opacity(0.9)
                    : Color.white.opacity(0.2)
            )
            .lineLimit(1)
            .frame(maxWidth: 72)
    }
}
```

with:

```swift
let effective = state.dynamicActions[i] ?? seg.actions
let clampedIdx = effective.isEmpty ? 0 : min(
    state.actionIndices[i] ?? seg.stickyIndex,
    effective.count - 1
)

VStack(spacing: 3) {
    SegmentIconView(segment: seg, highlighted: highlighted)

    Text(seg.label)
        .font(.system(size: 11, weight: highlighted ? .semibold : .regular))
        .foregroundStyle(highlighted ? Color.white : Color.white.opacity(0.38))
        .fixedSize()

    // Sub-label for level-2 segments (static) or any dynamic segment
    if effective.count > 1 {
        Text(effective[clampedIdx].displayLabel)
            .font(.system(size: 9))
            .foregroundStyle(
                highlighted
                    ? Color(red: 0.7, green: 0.65, blue: 1.0).opacity(0.9)
                    : Color.white.opacity(0.2)
            )
            .lineLimit(1)
            .frame(maxWidth: 72)
    }
}
```

- [ ] **Step 3: Add dynamic population helpers to `WheelController.swift`**

Add the following private methods to `WheelController` (before the closing brace, after `toViewCoord`):

```swift
// ─────────────────────────────────────────────────────────────────────────
// MARK: Dynamic segments
// ─────────────────────────────────────────────────────────────────────────

/// Returns populated dynamic actions for `segmentIndex` if available,
/// falling back to the segment's static actions array.
private func effectiveActions(for segmentIndex: Int) -> [BibloAction] {
    state.dynamicActions[segmentIndex] ?? wheel.segments[segmentIndex].actions
}

/// For each segment with a dynamicCommand, runs that command in parallel
/// (1-second timeout per command) and stores results in state.dynamicActions.
/// Blocks the calling thread — call before showing the wheel.
private func populateDynamicSegments() {
    let indexed = wheel.segments.enumerated().filter { $0.element.dynamicCommand != nil }
    guard !indexed.isEmpty else { return }

    let group = DispatchGroup()
    var results: [Int: [BibloAction]] = [:]
    let lock = NSLock()

    for (i, seg) in indexed {
        guard let raw = seg.dynamicCommand, !raw.isEmpty else { continue }
        let cmd = VariableResolver.resolve(raw)
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let actions = self.runDynamicCommand(cmd)
            lock.lock()
            results[i] = actions
            lock.unlock()
            group.leave()
        }
    }

    // Wait up to 1 second total (per-command timeout is inside runDynamicCommand)
    _ = group.wait(timeout: .now() + 1.0)
    state.dynamicActions = results
}

/// Executes `command` via /bin/zsh -lc with a 1-second timeout.
/// Each non-empty output line becomes a runShell action.
/// Returns at most 8 actions (wheel segment limit).
private func runDynamicCommand(_ command: String) -> [BibloAction] {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    task.arguments     = ["-lc", command]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError  = Pipe()  // discard stderr

    guard (try? task.run()) != nil else { return [] }

    // Poll with 1-second deadline (avoids blocking group thread indefinitely)
    let deadline = Date().addingTimeInterval(1.0)
    while task.isRunning && Date() < deadline {
        Thread.sleep(forTimeInterval: 0.01)
    }
    if task.isRunning { task.terminate() }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else { return [] }

    return output
        .split(separator: "\n", omittingEmptySubsequences: true)
        .prefix(8)
        .map { BibloAction.runShell(command: String($0), captureOutput: false) }
}
```

- [ ] **Step 4: Call `populateDynamicSegments()` in `handleKeyDown()`**

In `handleKeyDown()`, add the call **before** `backdrop.orderFront(nil)`:

```swift
private func handleKeyDown() {
    keyDownDate = Date()
    let cursor = NSEvent.mouseLocation

    activeScreen = NSScreen.screens.first { $0.frame.contains(cursor) } ?? NSScreen.main

    guard let screen = activeScreen else { return }

    panel.setFrame(screen.frame,    display: false)
    backdrop.setFrame(screen.frame, display: false)

    state.wheelOrigin = toViewCoord(cursor, screen: screen)
    state.highlightedIndex = nil
    state.dynamicActions = [:]   // clear stale results from last open

    // Populate dynamic segments before showing — blocks briefly for fast commands
    populateDynamicSegments()

    backdrop.orderFront(nil)
    panel.makeKeyAndOrderFront(nil)

    startTracking()
}
```

- [ ] **Step 5: Use `effectiveActions` in `handleScroll`**

Replace:
```swift
let seg = wheel.segments[idx]
guard seg.actions.count > 1 else { return }

var cur = stickyIndices[idx] ?? 0
cur = delta < 0
    ? (cur + 1) % seg.actions.count
    : (cur - 1 + seg.actions.count) % seg.actions.count
```
with:
```swift
let actions = effectiveActions(for: idx)
guard actions.count > 1 else { return }

var cur = stickyIndices[idx] ?? 0
cur = delta < 0
    ? (cur + 1) % actions.count
    : (cur - 1 + actions.count) % actions.count
```

- [ ] **Step 6: Use `effectiveActions` in `handleKeyUp` (tap-repeat path)**

Replace:
```swift
let seg = wheel.segments[last.segmentIdx]
guard !seg.actions.isEmpty else { return }
let action = seg.actions[min(last.actionIdx, seg.actions.count - 1)]
```
with:
```swift
let actions = effectiveActions(for: last.segmentIdx)
guard !actions.isEmpty else { return }
let action = actions[min(last.actionIdx, actions.count - 1)]
```

- [ ] **Step 7: Use `effectiveActions` in `handleKeyUp` (normal release path)**

Replace:
```swift
let seg = wheel.segments[idx]
guard !seg.actions.isEmpty else { return }
let actionIdx = min(stickyIndices[idx] ?? 0, seg.actions.count - 1)
let action = seg.actions[actionIdx]
```
with:
```swift
let actions = effectiveActions(for: idx)
guard !actions.isEmpty else { return }
let actionIdx = min(stickyIndices[idx] ?? 0, actions.count - 1)
let action = actions[actionIdx]
```

- [ ] **Step 8: Use `effectiveActions` in `fireCurrentSegment`**

Replace:
```swift
let seg = wheel.segments[idx]
guard !seg.actions.isEmpty else { return }
let actionIdx = min(stickyIndices[idx] ?? 0, seg.actions.count - 1)

stickyIndices[idx] = actionIdx
lastFired = (idx, actionIdx)

keyDownDate = nil
stopTracking()
panel.orderOut(nil)
backdrop.orderOut(nil)
state.highlightedIndex = nil

ActionExecutor.execute(seg.actions[actionIdx])
```
with:
```swift
let actions = effectiveActions(for: idx)
guard !actions.isEmpty else { return }
let actionIdx = min(stickyIndices[idx] ?? 0, actions.count - 1)

stickyIndices[idx] = actionIdx
lastFired = (idx, actionIdx)

keyDownDate = nil
stopTracking()
panel.orderOut(nil)
backdrop.orderOut(nil)
state.highlightedIndex = nil

ActionExecutor.execute(actions[actionIdx])
```

- [ ] **Step 9: Type-check**

```bash
cd apps/biblo && swiftc -typecheck -target arm64-apple-macosx13.0 \
  -framework AppKit -framework Carbon -framework SwiftUI -framework Combine \
  $(find Sources -name "*.swift" | tr '\n' ' ')
```

Expected: 0 errors.

- [ ] **Step 10: Manual smoke test**

Add a test segment to `~/.config/biblo/wheels.json`:
```json
{
  "label": "Branches",
  "icon": "arrow.triangle.branch",
  "type": "actionOnly",
  "stickyIndex": 0,
  "actions": [],
  "dynamicCommand": "echo 'git checkout main\ngit checkout develop\ngit checkout staging'"
}
```
Rebuild and run. Hold hotkey — the Branches segment should show sub-labels cycling through the three `git checkout` commands when scrolled. Selecting one should run that shell command.

- [ ] **Step 11: Commit**

```bash
git add apps/biblo/Sources/Views/WheelState.swift \
        apps/biblo/Sources/Views/WheelView.swift \
        apps/biblo/Sources/Controller/WheelController.swift
git commit -m "feat(biblo): dynamic segments — populate actions from shell command at open time"
```

---

### Task 5: ToastWindow + show on captureOutput

**Files:**
- Create: `apps/biblo/Sources/Window/ToastWindow.swift`
- Modify: `apps/biblo/Sources/Controller/WheelController.swift`

**Interfaces:**
- Consumes: `ActionExecutor.execute(_:onCapture:)` from Task 3
- Produces: `ToastWindow.show(message: String, on: NSScreen?)` — displayed for 1.5 seconds, then auto-dismissed; `WheelController.fireAction(_:)` — replaces bare `ActionExecutor.execute` calls in the controller

**Toast appearance:** Floating pill at top-center of active screen. `ultraThinMaterial` background, white text, green checkmark icon, 1.5-second auto-dismiss.

- [ ] **Step 1: Create `ToastWindow.swift`**

```swift
import AppKit
import SwiftUI

/// Floating auto-dismiss confirmation shown after captureOutput succeeds.
final class ToastWindow: NSPanel {

    init() {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 300, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        ignoresMouseEvents = true
    }

    /// Show `message` centred near the top of `screen` for 1.5 seconds.
    func show(message: String, on screen: NSScreen? = NSScreen.main) {
        let width: CGFloat = 300
        let height: CGFloat = 48
        let hosting = NSHostingView(rootView: ToastView(message: message))
        hosting.frame = CGRect(x: 0, y: 0, width: width, height: height)
        contentView = hosting

        let target = screen ?? NSScreen.main ?? NSScreen.screens[0]
        let x = target.frame.midX - width / 2
        let y = target.frame.maxY - 80
        setFrame(CGRect(x: x, y: y, width: width, height: height), display: true)

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(dismiss), object: nil)
        orderFront(nil)
        perform(#selector(dismiss), with: nil, afterDelay: 1.5)
    }

    @objc private func dismiss() {
        orderOut(nil)
    }
}

// ── Toast view ────────────────────────────────────────────────────────────────

private struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 15))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 2: Add `toast` property to `WheelController` and `fireAction` helper**

In `WheelController.swift`, add `toast` to the windows section (after `let backdrop = BackdropWindow()`):

```swift
private let toast = ToastWindow()
```

Add the `fireAction` helper to the private helpers section (before `cancelAndClose`):

```swift
/// Executes `action` and shows a toast if it captured output.
private func fireAction(_ action: BibloAction) {
    ActionExecutor.execute(action) { [weak self] output in
        guard !output.isEmpty else { return }
        self?.toast.show(
            message: "Copied \(output.count) char\(output.count == 1 ? "" : "s")",
            on: self?.activeScreen
        )
    }
}
```

- [ ] **Step 3: Replace bare `ActionExecutor.execute` calls with `fireAction`**

There are three call sites in `WheelController`. Replace each:

**In `handleKeyUp()` — tap-repeat path:**
```swift
// OLD:
ActionExecutor.execute(action)
// NEW:
fireAction(action)
```

**In `handleKeyUp()` — normal release path:**
```swift
// OLD:
ActionExecutor.execute(action)
// NEW:
fireAction(action)
```

**In `fireCurrentSegment()` — Return key path:**
```swift
// OLD:
ActionExecutor.execute(seg.actions[actionIdx])
// NEW (now uses effectiveActions result from Task 4 Step 8):
fireAction(actions[actionIdx])
```

- [ ] **Step 4: Type-check**

```bash
cd apps/biblo && swiftc -typecheck -target arm64-apple-macosx13.0 \
  -framework AppKit -framework Carbon -framework SwiftUI -framework Combine \
  $(find Sources -name "*.swift" | tr '\n' ' ')
```

Expected: 0 errors.

- [ ] **Step 5: Manual smoke test for captureOutput**

Add a test action to `~/.config/biblo/wheels.json`:
```json
{
  "type": "runShell",
  "command": "git -C ~/Documents rev-parse --short HEAD",
  "captureOutput": true
}
```
Rebuild, run, trigger that action. Confirm:
1. Toast appears at top-center of screen showing "Copied N chars"
2. `pbpaste` in terminal shows the git short SHA

- [ ] **Step 6: Manual smoke test for variable substitution**

Add a test action:
```json
{
  "type": "runShell",
  "command": "echo 'Running in {{frontapp.bundle}} on {{date}}' > /tmp/biblo-test.txt"
}
```
Trigger with Finder in foreground. Confirm `/tmp/biblo-test.txt` contains `com.apple.finder` and today's date.

- [ ] **Step 7: Commit**

```bash
git add apps/biblo/Sources/Window/ToastWindow.swift \
        apps/biblo/Sources/Controller/WheelController.swift
git commit -m "feat(biblo): ToastWindow + fireAction — confirm captureOutput to clipboard"
```

---

## Self-Review

### Spec coverage

| Feature | Tasks |
|---------|-------|
| Dynamic segments | Task 1 (model), Task 4 (population + view) |
| Variable substitution | Task 2 (resolver), Task 3 (wired into executor) |
| Shell output capture → clipboard | Task 3 (captureShell in executor) |
| Toast confirmation | Task 5 |
| PLAN.md updated | Task 0 |

### Placeholder scan

None — all steps contain concrete code.

### Type consistency

- `BibloAction.runShell(command: String, captureOutput: Bool)` — defined Task 1, used with correct labels in Tasks 3, 4.
- `WheelState.dynamicActions: [Int: [BibloAction]]` — defined Task 4 Step 1, read in WheelView Task 4 Step 2, written in WheelController Task 4 Steps 3–4.
- `VariableResolver.resolve(_ template: String) -> String` — defined Task 2, called in Tasks 3 and 4.
- `ActionExecutor.execute(_ action: BibloAction, onCapture: ((String) -> Void)? = nil)` — defined Task 3, called via `fireAction` wrapper in Task 5.
- `ToastWindow.show(message: String, on: NSScreen?)` — defined Task 5 Step 1, called in Task 5 Step 2.

All consistent. ✓
