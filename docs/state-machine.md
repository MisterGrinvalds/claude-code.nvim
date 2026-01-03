# Claude Code State Machine

## Overview

The state machine tracks Claude's current activity via file-based IPC between Claude Code CLI and Neovim.

```
~/.claude/state/current.json  <-- State file (processing/waiting/done)
~/.claude/state/status.json   <-- Status file (model, tokens, cost)
~/.claude/state/refresh       <-- Buffer refresh signal
```

## State Diagram

```
                              ┌─────────────────────────────────────┐
                              │           CLAUDE CODE CLI           │
                              └─────────────────────────────────────┘
                                              │
                    ┌─────────────────────────┼─────────────────────────┐
                    │                         │                         │
                    ▼                         ▼                         ▼
         ┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
         │ UserPromptSubmit │      │    PreToolUse    │      │   Notification   │
         │                  │      │                  │      │ (permission_     │
         │  on-prompt.sh    │      │ on-tool-start.sh │      │      prompt)     │
         └────────┬─────────┘      └────────┬─────────┘      │ on-permission.sh │
                  │                         │                └────────┬─────────┘
                  │                         │                         │
                  ▼                         ▼                         ▼
         ┌──────────────────────────────────────────────────────────────────────┐
         │                                                                      │
         │                    ~/.claude/state/current.json                      │
         │                                                                      │
         │   {"state": "processing"|"waiting"|"done", "timestamp": 1234567890}  │
         │                                                                      │
         └──────────────────────────────────┬───────────────────────────────────┘
                                            │
                    ┌───────────────────────┼───────────────────────┐
                    │                       │                       │
                    ▼                       ▼                       ▼
         ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
         │  PostToolUse     │    │      Stop        │    │   statusLine     │
         │ (Write|Edit)     │    │                  │    │    (bridge)      │
         │ on-file-write.sh │    │   on-stop.sh     │    │ statusline-      │
         └────────┬─────────┘    └────────┬─────────┘    │   bridge.sh      │
                  │                       │              └────────┬─────────┘
                  ▼                       ▼                       ▼
         ┌────────────────┐      ┌────────────────┐      ┌────────────────┐
         │ ~/.claude/     │      │ state: "done"  │      │ ~/.claude/     │
         │ state/refresh  │      │                │      │ state/         │
         │ (timestamp)    │      │                │      │ status.json    │
         └────────────────┘      └────────────────┘      └────────────────┘
                  │                       │                       │
                  └───────────────────────┼───────────────────────┘
                                          │
                                          ▼
                              ┌─────────────────────────────────────┐
                              │     NEOVIM (file watchers)          │
                              │                                     │
                              │  statusline.lua  ←── current.json   │
                              │  statusline.lua  ←── status.json    │
                              │  sync.lua        ←── refresh        │
                              └─────────────────────────────────────┘
```

## State Transitions

```
┌───────┐  UserPromptSubmit   ┌────────────┐
│ idle  │ ─────────────────▶  │ processing │ ◀─┐
└───────┘                     └────────────┘   │
    ▲                               │          │
    │                               │          │ PreToolUse
    │ (2s timer)                    │          │ (after permission granted)
    │                               ▼          │
    │                     ┌─────────────────┐  │
    │                     │ Notification:   │  │
    │                     │ permission_     │ ─┘
    │                     │ prompt          │
    │                     │                 │
    │                     │  state:waiting  │
    │                     └─────────────────┘
    │                               │
    │                               │ (60s timeout - permission denied recovery)
    │                               ▼
    │     ┌──────┐         ┌───────────────┐
    └──── │ done │ ◀────── │     Stop      │
          └──────┘         └───────────────┘
```

## Hook Scripts Explained

### 1. on-prompt.sh (UserPromptSubmit)

**Trigger:** User presses Enter to send a prompt to Claude

**Action:** Sets state to `processing`

```bash
STATE_FILE="$HOME/.claude/state/current.json"
mkdir -p "$(dirname "$STATE_FILE")"
echo '{"state": "processing", ...}' > "$STATE_FILE"
```

**Why:** Indicates Claude is now thinking/working on the request.

---

### 2. on-tool-start.sh (PreToolUse)

**Trigger:** Claude is about to use ANY tool (Read, Write, Bash, etc.)

**Action:** Sets state to `processing`

```bash
STATE_FILE="$HOME/.claude/state/current.json"
mkdir -p "$(dirname "$STATE_FILE")"
echo '{"state": "processing", ...}' > "$STATE_FILE"
```

**Why:** This is CRITICAL for the `waiting → processing` transition. When user grants permission, Claude immediately uses a tool, which triggers PreToolUse and moves state back to `processing`.

---

### 3. on-permission.sh (Notification: permission_prompt)

**Trigger:** Claude needs user permission for a sensitive operation

**Action:** Sets state to `waiting`

```bash
STATE_FILE="$HOME/.claude/state/current.json"
mkdir -p "$(dirname "$STATE_FILE")"
echo '{"state": "waiting", ...}' > "$STATE_FILE"
```

**Why:** Shows the user that Claude is blocked and needs input. The statusline can display a different icon/color to draw attention.

---

### 4. on-stop.sh (Stop)

**Trigger:** Claude finishes responding (end of turn)

**Action:** Sets state to `done`

```bash
STATE_FILE="$HOME/.claude/state/current.json"
mkdir -p "$(dirname "$STATE_FILE")"
echo '{"state": "done", ...}' > "$STATE_FILE"
```

**Why:** Indicates Claude has finished. Neovim shows "done" for 2 seconds, then transitions to `idle`.

---

### 5. on-file-write.sh (PostToolUse: Write|Edit|MultiEdit)

**Trigger:** Claude successfully wrote/edited a file

**Action:** Writes timestamp to refresh file

```bash
REFRESH_FILE="$HOME/.claude/state/refresh"
mkdir -p "$(dirname "$REFRESH_FILE")"
date +%s > "$REFRESH_FILE"
```

**Why:** Signals Neovim to run `:checktime` and reload any buffers that changed on disk.

---

## Neovim Side (statusline.lua)

```lua
-- File watcher triggers on current.json change
local function on_state_update()
  M.read_state()           -- Read new state from file
  refresh_lualine()        -- Immediately update statusline

  -- "done" → "idle" after 2 seconds
  if cached_state.state == 'done' then
    vim.defer_fn(function()
      cached_state = { state = 'idle' }
      refresh_lualine()
    end, 2000)
  end

  -- "waiting" → "idle" after 60 seconds (permission denial recovery)
  if cached_state.state == 'waiting' then
    vim.defer_fn(function()
      if cached_state.state == 'waiting' then
        cached_state = { state = 'idle' }
        refresh_lualine()
      end
    end, 60000)
  end
end
```

## Settings.json Configuration

```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "hooks": [{ "type": "command", "command": "~/.claude/hooks/on-prompt.sh" }]
    }],
    "PreToolUse": [{
      "matcher": "",
      "hooks": [{ "type": "command", "command": "~/.claude/hooks/on-tool-start.sh" }]
    }],
    "Notification": [{
      "matcher": "permission_prompt",
      "hooks": [{ "type": "command", "command": "~/.claude/hooks/on-permission.sh" }]
    }],
    "PostToolUse": [{
      "matcher": "Write|Edit|MultiEdit",
      "hooks": [{ "type": "command", "command": "~/.claude/hooks/on-file-write.sh" }]
    }],
    "Stop": [{
      "hooks": [{ "type": "command", "command": "~/.claude/hooks/on-stop.sh" }]
    }]
  }
}
```

## Statusline Icons & Colors

| State | Icon | Color | Meaning |
|-------|------|-------|---------|
| idle | 󰚩 | #6c7086 (gray) | Ready for input |
| processing | 󰦖 | #f9e2af (yellow) | Claude is working |
| waiting | 󰋗 | #fab387 (peach) | Needs user permission |
| done | 󰄬 | #a6e3a1 (green) | Just finished |

## Edge Cases Handled

1. **Permission Denied:** No hook fires when user denies. 60-second timeout recovers to `idle`.

2. **Rapid State Changes:** 50ms debounce prevents flickering from rapid file writes.

3. **Multiple Tool Calls:** PreToolUse fires for each tool, but state is already `processing` so it's a no-op.

4. **Neovim Restart:** Reads current state file on startup, picks up where Claude left off.
