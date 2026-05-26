# Safe Delete — Slash Command Reference

## Overview

Safe-delete provides slash commands for runtime control. Commands work on **all platforms**: Cursor, Claude Code, OpenCode, Codex, Copilot CLI, Gemini CLI, and any agentic terminal.

---

## Command Table

| Command | What It Does | Default | Platform Support |
|---------|-------------|---------|------------------|
| `/safe-delete` | Show current status and mode | — | All |
| `/safe-delete on` | Enable full safe-delete (always-bound + watcher offer + trigger detection) | ✅ Default | All |
| `/safe-delete off` | Disable safe-delete entirely. No proactive watching. Only activates on explicit trigger words + pending delete operation. | ❌ | All |
| `/safe-delete watcher` | Manually deploy the background deletion watcher sub-agent for the current task | Off (offered per-task) | All |
| `/safe-delete status` | Display state, recent activity log, current mode, and audit stats | — | All |
| `/safe-delete uninstall` | **Self-destruct** — remove safe-delete binding from agent config, optionally delete skill files. Triple confirm required. | ❌ (must type explicitly) | All |

---

## State Machine

```
          ┌─────────────────────────────────────────────┐
          │              START SESSION                    │
          │  Read config: AGENTS.md / CLAUDE.md / etc.   │
          │  Read env:    $SAFE_DELETE                   │
          └──────────────────┬──────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │  EVALUATE MODE │
                    └───────┬────────┘
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │  ON      │ │ OFF      │ │ WATCHER  │
        │ (default)│ │          │ │          │
        └────┬─────┘ └────┬─────┘ └────┬─────┘
             │            │            │
             ▼            ▼            ▼
    ┌────────────────┐ ┌──────────┐ ┌────────────────┐
    │ Always-bound   │ │ Trigger  │ │ Always-bound   │
    │ plan analysis  │ │ words    │ │ plan analysis  │
    │ Watcher offer  │ │ ONLY     │ │ + auto-watcher │
    │ Full protocol  │ │ + delete │ │ Full protocol  │
    └────────────────┘ │ modal    │ └────────────────┘
                       └──────────┘

    User types / command ──→ changes state ──→ persists for session
    User types /safe-delete ──→ shows current state
```

---

## Detailed Command Behaviour

### `/safe-delete` (status check)

Shows current state without changing anything:

```
🛡️ Safe-Delete Status
  Mode:        ACTIVE (default)
  Watcher:     idle
  Trigger:     always-bound + semantic
  Last action: node_modules cleaned (2026-05-26, risk 4) → Recycle Bin
  Audit log:   C:\Users\Uncod\.opencode-trash\deletion-log.txt
  Backups:     3 active in safekeeper
  Config:      %APPDATA%\.opencode-safekeeper\
```

### `/safe-delete on`

Restores full safe-delete protection:

| Feature | Status |
|---------|--------|
| Always-bound plan analysis | ✅ Checks every task for deletion risk |
| Sub-agent watcher offer | ✅ Offered before complex tasks |
| Semantic trigger detection | ✅ Full trigger word list active |
| Delete modal (5 options) | ✅ Always shown |
| Risk scoring | ✅ Always calculated |
| Backup & safekeeper | ✅ Always on |
| `/instant` mode | ✅ Available |

### `/safe-delete off`

Reduces safe-delete to trigger-only mode:

| Feature | Status |
|---------|--------|
| Always-bound plan analysis | ❌ Skipped |
| Sub-agent watcher offer | ❌ Not offered |
| Semantic trigger detection | ✅ Still active (primary activation path) |
| Delete modal (5 options) | ✅ Shown when triggered |
| Risk scoring | ✅ Calculated when triggered |
| Backup & safekeeper | ✅ On when triggered |
| `/instant` mode | ✅ Available |

**OFF does not mean unprotected.** It means the agent won't proactively look for deletion opportunities. If the user explicitly says "delete X" or uses a semantic trigger word, the full protocol activates.

**When to use OFF:**
- You're doing data exploration (read-only)
- You're reviewing code (no modification)
- You're doing a series of intentional, user-directed deletions
- The always-bound check is slowing down your workflow

### `/safe-delete watcher`

Manually deploy the background watcher sub-agent. Useful if:
- The task started without the watcher offer (user chose "No")
- Mid-task the user realizes deletions will happen
- The user changed their mind and wants protection now

The watcher runs in the background during task execution, intercepts all file removal operations, and presents the delete modal automatically.

### `/safe-delete status`

Extended status display:

```
🛡️ Safe-Delete Status — Extended
  Mode:            ACTIVE
  Watcher:         idle (not deployed)
  Session start:   2026-05-26 14:32:01
  Last action:     node_modules cleaned (2026-05-26, risk 4) → Recycle Bin
  Audit entries:   47 total
  ── deleted:      32
  ── skipped:      10
  ── backed up:    5
  ── permanent:    0
  Backups active:  3 in safekeeper
  Total protected: ~850 MB
  Config path:     %LOCALAPPDATA%\.opencode-safekeeper\

  To change mode:
    /safe-delete on     — full protection (default)
    /safe-delete off    — trigger-only
    /safe-delete watcher — deploy background watcher
    /safe-delete uninstall — remove safe-delete entirely (triple confirm)
```

### `/safe-delete uninstall`

**⚠ DANGER: This command removes safe-delete from your agent configuration.**

Self-destruction protocol — requires triple confirmation with written reason:

```
┌──────────────────────────────────────────────────────────────┐
│ ⚠ DANGER: Safe-Delete Uninstall                              │
│                                                              │
│ This will:                                                    │
│   1. Remove safe_delete setting from your agent config file   │
│   2. Optionally delete skill files from disk                  │
│   3. Delete the audit log (optional)                          │
│                                                              │
│ Risk: 10/10 (CATASTROPHIC) — no recovery once confirmed       │
│                                                              │
│ [CONFIRM 1/3] Are you sure you want to uninstall? (y/N)      │
│ [CONFIRM 2/3] Type written reason: "Because ________"        │
│ [CONFIRM 3/3] Final confirmation: Type "UNINSTALL"           │
│                                                              │
│ Options after confirm:                                        │
│   [a] Remove binding only (keep skill files on disk)         │
│   [b] Remove binding + delete ALL skill files (irreversible) │
│   [c] Cancel — don't uninstall                               │
└──────────────────────────────────────────────────────────────┘
```

**What happens on confirm:**

| Action | Option [a] (binding only) | Option [b] (full uninstall) |
|--------|--------------------------|-----------------------------|
| AGENTS.md / CLAUDE.md edit | ✅ Remove `safe_delete:` line | ✅ Remove `safe_delete:` line |
| Skill directory deletion | ❌ Keep files | ✅ Recycle Bin (not permanent) |
| Audit log deletion | ❌ Keep | ✅ Move to Recycle Bin |
| Session state | 🔄 Reset to inactive | 🔄 Reset to inactive |
| Backups / safekeeper | ❌ Keep (inactive) | ✅ Delete with 30d grace prompt |
| Platform config (all 6) | ✅ Remove binding from active | ✅ Remove from all found |

**What happens on cancel:** Nothing. The command is aborted entirely.

**Recovery after uninstall:**
- Option [a]: Re-bind by manually adding `safe_delete: on` to your agent config
- Option [b]: Restore skill files from Recycle Bin, then re-bind via config

### Example

```
User: "/safe-delete uninstall"
Agent: "⚠ This will remove safe-delete from your agent.
        Risk: 10/10 — CATASTROPHIC

        Confirm 1/3: Are you sure? (y/N)"
User: "y"
Agent: "Confirm 2/3: Written reason for uninstalling?"
User: "Because I'm switching to a different safety tool"
Agent: "Confirm 3/3: Type UNINSTALL to proceed"
User: "UNINSTALL"
Agent: "Safe-delete uninstalled successfully.

        What was done:
          ✓ Removed safe_delete from AGENTS.md
          [a] Removed binding only (files kept on disk)
          ✓ Backups preserved in safekeeper (48h TTL)

        To re-install: git clone <repo> + add safe_delete: on to your config"
```

### State Impact

```
                          ┌──────────────────┐
                          │   UNINSTALLED     │
                          │  (terminal state) │
                          │ No safe-delete    │
                          │ No watcher, no    │
                          │ triggers, nothing │
                          └──────────────────┘
```

**Uninstalled means:**
- No safe-delete whatsoever — not even trigger words
- No backup, no safekeeper, no audit log
- No watcher, no always-bound checks
- The agent treats safe-delete as non-existent
- **Only way to restore:** manual re-install or Recycle Bin recovery

---

## Persistent Configuration

Your choice is remembered across sessions by setting it in your agent config file:

### AGENTS.md (OpenCode)
```markdown
# Agent settings
safe_delete: off
```

### CLAUDE.md (Claude Code)
```markdown
# Agent settings
safe_delete: on
```

### .cursorrules (Cursor)
```yaml
safe_delete: watcher
```

### GEMINI.md (Gemini CLI)
```markdown
# Agent settings
safe_delete: off
```

### Environment variable (ALL platforms)
```bash
SAFE_DELETE=on        # Enable (default)
SAFE_DELETE=off       # Disable
SAFE_DELETE=watcher   # Enable with auto-watcher
```

---

## Platform-Specific Implementation

### Claude Code
Commands are processed as natural language in the chat. The agent parses `/safe-delete` patterns from user messages.

Implementation pattern:
```python
if user_message.startswith("/safe-delete"):
    command = user_message.split()[1] if len(user_message.split()) > 1 else "status"
    # apply state transition
```

### OpenCode
Same as Claude Code. Commands processed as chat messages.

### Cursor
Commands work in chat/composer. The agent detects the `/safe-delete` prefix and applies state.

### Copilot CLI
Commands work in conversational mode. The agent detects `/safe-delete` and responds.

### Gemini CLI
Commands work as natural language. The agent detects the prefix.

### Codex (terminal-based)
Same pattern — commands processed as chat input.

### Generic any agent
If the platform doesn't support slash commands natively, the agent detects `"/safe-delete"` pattern in user input and processes it as a command.

---

## Do Not

- Do NOT silently ignore `/safe-delete off` — acknowledge the state change
- Do NOT skip the status display on `/safe-delete` — always show current mode
- Do NOT reset to default on session boundary — read persistent config
- Do NOT treat "off" as "unprotected" — trigger detection still works
- Do NOT offer the sub-agent watcher when mode is OFF
- Do NOT run always-bound plan analysis when mode is OFF
- Do NOT persist command-line changes to config file without asking
- Do NOT accept unknown commands — show "Unknown command. Try /safe-delete on|off|watcher|status|uninstall"
- Do NOT run uninstall without triple confirmation — it's risk 10 (catastrophic)
- Do NOT delete skill files permanently — always use Recycle Bin
- Do NOT delete safekeeper backups without asking — prompt with "Delete safekeeper backups? (30 days grace available)"
- Do NOT silently uninstall — log the uninstall event to deletion-log.txt first
