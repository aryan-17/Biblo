# Biblo

A GTA V-style radial command wheel for macOS. Hold a hotkey, flick a direction, release — apps open, commands run, URLs load. No mouse required, no menus, no context switching.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

---

## How it works

1. Hold your hotkey (default: Option+Space)
2. Flick the cursor toward any of the 8 segments
3. Release — action fires instantly

For segments with multiple actions, push the cursor further out into the outer ring, or press **Enter** to enter the outer ring via keyboard.

---

## Actions

| Type | What it does |
|---|---|
| `launchApp` | Focus or launch an app by bundle ID |
| `openURL` | Open a URL in a specific browser |
| `openProject` | Open a folder in VS Code, Cursor, IntelliJ, etc. |
| `runInTerminal` | Run a shell command in a new terminal tab |
| `runShell` | Run any shell command silently |
| `runShortcut` | Trigger an Apple Shortcuts shortcut |
| `runAppleScript` | Execute an AppleScript |
| `openFile` | Open a file with its default app |

---

## Configuration

Edit `~/.config/biblo/wheels.json`:

```json
{
  "wheels": [
    {
      "id": "main",
      "hotkey": { "key": "Space", "modifiers": ["option"] },
      "segments": [
        {
          "label": "Terminal",
          "icon": "terminal",
          "type": "appWithActions",
          "stickyIndex": 0,
          "actions": [
            { "type": "launchApp", "bundleID": "dev.warp.Warp-Stable" },
            { "type": "runInTerminal", "command": "cd ~/project && git status", "terminalBundleID": "dev.warp.Warp-Stable" }
          ]
        }
      ]
    }
  ]
}
```

Changes are picked up on next wheel open — no restart needed.

---

## Keyboard navigation

| Key | Action |
|---|---|
| Arrow keys | Navigate between segments |
| 1–8 | Jump directly to segment |
| Enter | Enter outer ring (if sub-actions exist) |
| ← → | Cycle outer ring items |
| Enter (in outer ring) | Fire selected sub-action |
| Esc | Cancel |
| Scroll | Cycle sub-actions within highlighted segment |

---

## Install

1. Download `Biblo-0.1.0.dmg` from [Releases](../../releases/latest)
2. Drag Biblo to Applications
3. Right-click → Open → Open (one-time Gatekeeper bypass — not yet notarized)

**Requires macOS 13 Ventura or later · Apple Silicon**

---

## Build from source

```bash
git clone https://github.com/aryan-17/Biblo
cd Biblo/apps/biblo
xcodegen generate
xcodebuild -scheme Biblo -configuration Debug build
```

Requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).
