# Agent Behaviour for Delete Operations

## Purpose

Define how the agent should **think, react, and decide** when any deletion-adjacent intent is detected — including during coding/refactoring/fixing tasks where deletion is a side effect, not the goal. This controls the agent's mindset, reflexes, and judgment.

---

## Command Integration

Before any action, check the current safe-delete state. The user controls this via commands or persistent config:

| Source | Check Priority |
|--------|----------------|
| Session `SAFE_DELETE` env var | Highest (overrides all) |
| `/safe-delete` command issued this session | Second |
| `/safe-delete uninstall` sets state to UNINSTALLED (terminal) | Overrides all |
| Agent config file (AGENTS.md / CLAUDE.md / GEMINI.md / .cursorrules) | Third |
| Default: ON | Fallback |

The agent reads these at session start and after every `/safe-delete` command.

See `commands.md` for full command syntax and behaviour.

---

## State: UNINSTALLED (Terminal)

When the user issues `/safe-delete uninstall` and completes triple confirmation:

- Safe-delete is **completely removed** from the session
- No always-bound checks, no watcher, no trigger detection, no modals
- No backup, no safekeeper, no audit logging
- The agent treats safe-delete as non-existent for this session
- **Only way to restore:** manual re-install from git or Recycle Bin restore
- Transition diagram:
  ```
  ON / OFF / WATCHER → UNINSTALLED → [manual re-install only]
  UNINSTALLED → ON: ❌ impossible via command
  ```

The agent MUST confirm the uninstall was logged (writes final audit entry before disabling itself).

---

## State: ON (Default)

This skill is **always active** during every agent session. Even if the task says "refactor module X" or "fix bug Y" — if your execution plan involves removing, replacing, overwriting, or renaming any file, safe-delete activates.

**You do not need a trigger word. You need a trigger intention.**

---

## State: OFF

When the user issues `/safe-delete off`:

- Skip always-bound plan analysis — do not proactively check for deletion risk
- Do NOT offer the sub-agent watcher before tasks
- **Trigger word detection still active** — if the user says "delete" or uses a semantic trigger, AND a delete operation is about to happen, the full protocol activates
- The delete modal, risk scoring, backup, and safekeeper all remain available but dormant until triggered

### When OFF, this behaviour changes:

- Decision flow starts at Step 2 (check semantic triggers) instead of Step 0 (plan analysis)
- Watcher offer step is skipped entirely
- The 3 Cognitive Checks still run when trigger words are detected

### Transitioning OFF → ON:

- User types `/safe-delete on` → full protection restored immediately
- Next task will get always-bound analysis and watcher offer

---

## Pre-Task Sub-Agent Deletion Watcher

Before starting a complex task (refactoring, migration, cleanup, rebuild, bug fix that changes files), the agent MUST offer to deploy a background deletion watcher.

### The Offer Script:

```
┌──────────────────────────────────────────────────────────────────┐
│ ⚠ Task Analysis: Deletion May Be Required                        │
│                                                                  │
│ Your task: {short task description}                              │
│                                                                  │
│ My plan involves: {summary of what will be changed}               │
│                                                                  │
│ This may require deleting or replacing:                          │
│   - {file 1}                                                     │
│   - {file 2}                                                     │
│   - {files matching pattern}                                     │
│                                                                  │
│ Do you want me to deploy a background deletion watcher?           │
│ It will:                                                         │
│   - Monitor all file operations during the task                  │
│   - Pause before any delete and show a modal with options         │
│   - Ensure nothing is removed without your permission             │
│                                                                  │
│ [Yes — deploy watcher]  [No — rely on trigger words only]        │
└──────────────────────────────────────────────────────────────────┘
```

### If Yes (sub-agent deployed):

- The watcher sub-agent runs in the background during task execution
- Before any file removal, it intercepts and presents the delete modal (see `functions/fn-delete-modal.md`)
- The watcher logs all intercepted operations to the deletion diary
- The watcher does NOT slow down non-delete operations

### If No (no sub-agent):

- safe-delete remains active with semantic trigger detection
- The agent is responsible for self-monitoring its own actions
- Before any deletion during the task, the agent MUST pause and present the modal manually

---

## Semantic Triggers (For When Watcher Is Not Deployed)

Activate safe-delete mindset when the user says **anything semantically related to removal**, even if they don't say "delete":

### Direct triggers (obvious)
`delete`, `remove`, `erase`, `wipe`, `clear`, `destroy`, `trash`, `purge`, `nuke`, `clean up`, `clean out`, `free up space`

### Indirect triggers (nuanced)
`get rid of`, `throw away`, `toss`, `discard`, `dump`, `scrap`, `uninstall`, `unlink`, `deregister`, `revoke`, `expire`, `invalidate`

### Concealed triggers (easy to miss)
`make space`, `spring cleaning`, `organize`, `too much clutter`, `old files`, `junk`, `temp files`, `cache`, `logs`, `backups`, `old versions`, `duplicates`

### Data-altering triggers (not technically delete)
`move to trash`, `send to bin`, `archive`, `compress`, `reset`, `reformat`, `reinitialize`, `migrate`, `merge`, `deduplicate`, `overwrite`

### Environment-scope triggers (context matters)
`clean install`, `fresh start`, `start over`, `rebuild`, `reinstall`, `rollback`, `factory reset`, `restore defaults`

### Coding-task triggers (easy to miss during development)
`refactor`, `rename`, `replace`, `migrate`, `restructure`, `reorganize`, `redesign`, `rewrite`, `simplify`, `clean up code`, `remove dead code`, `extract`, `inline`, `move file`, `split module`, `merge modules`

---

## The 3 Cognitive Checks

When ANY trigger is detected OR when planning a coding task, immediately run these checks BEFORE any action:

### Check 1: "Is this actually a delete?"

```
User says: "refactor this module"
→ My plan: extract 2 functions, rename 1 file, delete 1 old file
→ IS a delete (old file will be removed)
→ safe-delete activates

User says: "clear npm cache"
→ This IS a delete (cache files removed)
→ safe-delete activates

User says: "reinstall node_modules"
→ This IS a delete (node_modules directory removed)
→ safe-delete activates

User says: "fix the login bug"
→ My plan: modify auth.js, add error handling
→ NOT a delete (no files removed)
→ safe-delete not triggered
```

### Check 2: "Does the user understand the scope?"

```
If user says "clear the cache":
  → Scope: {browser cache / npm cache / system cache / all caches?}
  → ASK: "Which cache specifically?"

If user says "delete old files":
  → Scope: {older than? / in which folder? / what file types?}
  → ASK: "What threshold counts as 'old'?"

If user says "clean up code":
  → Scope: {dead code / unused imports / whole files / functions only?}
  → ASK: "Which parts specifically? Shall I scan for unused exports first?"

If user says "free up space":
  → Scope: {any files? / specific drive? / how much space?}
  → RUN: disk usage analysis first
  → PRESENT: categorized breakdown with sizes
  → LET: user choose what to delete from curated options
```

### Check 3: "Is there a safer alternative?"

```
Before any delete, ask:
  - Could this go to Recycle Bin instead of permanent? (ALMOST ALWAYS YES)
  - Could this be archived instead of deleted?
  - Could this be renamed/disabled instead of removed?
  - Could this be moved to a backup location?
  - Is there a built-in cleanup tool (npm cache clean, Disk Cleanup, etc.)?
  - Could I refactor the code to not require deleting this file?
  - Could I deprecate instead of delete (add warning, keep file)?
```

---

## New Check: "Is this a coding task that might involve deletion?"

### When to Run This Check:
- At the START of any new task
- When writing an execution plan
- When the plan involves modifying existing files

### How to Determine:

```
My task: "Add error handling to auth.js"
Plan analysis:
  - Read auth.js (read — no deletion)
  - Modify auth.js (write — no deletion)
  - Add error-handler.js (create — no deletion)
  → NOT deletion-adjacent. Safe.

My task: "Split user.js into user-auth.js and user-profile.js"
Plan analysis:
  - Create user-auth.js (create — no deletion)
  - Create user-profile.js (create — no deletion)
  - Remove functions from user.js (modify — no deletion)
  - Delete user.js (DELETE — YES)
  → Deletion-adjacent. ACTIVATE safe-delete.
  → Offer sub-agent watcher to user.

My task: "Upgrade React 17 to React 18"
Plan analysis:
  - Update package.json (modify — no deletion)
  - Run npm install (install — no deletion)
  - npx react-codemod (may modify/rename/delete files)
  → UNCERTAIN. Run a dry-run first, then decide.
```

---

## Agent Stance Rules

### Rule 1: Always Present the Modal

Every delete goes through the modal. No exceptions. The modal gives the user 5 clear options.

### Rule 2: Curate, Don't Execute Blindly

When the user asks to "clean up" or "free space", never just delete. Instead:
1. Scan and categorize what's using space
2. Present a structured breakdown with sizes
3. Let the user choose specific targets from curated options
4. Only delete what they explicitly choose

### Rule 3: Pause on Frustration

If the user seems frustrated or impatient:
- Pause before any action
- Ask one extra clarifying question
- Do NOT skip the modal because "they seem sure"

### Rule 4: Default to Recycle Bin

**Every delete defaults to Recycle Bin.** Permanent deletion is never the default.

### Rule 5: Explain What Breaks

Before any delete, tell the user what will stop working.

### Rule 6: Offer an Undo Path

Every delete presentation must include recovery instructions.

### Rule 7: Respect the Question Tool

When using the platform's question tool, map confirmations appropriately:

| Risk | Question Tool Usage |
|------|-------------------|
| 1–3 | Single modal with proceed/cancel |
| 4–5 | Modal → backup → second modal "proceed?" |
| 6–7 | Modal → backup → second modal "ABSOLUTELY sure?" |
| 8–9 | Modal → backup → WCGW → modal → 30s delay → modal |
| 10 | Modal → backup → full analysis → written reason → 60s delay |

### Rule 8: Never Blindly Follow "Delete Everything"

If the user says "delete everything", "clean all", "remove all files", or any variant:
1. **DO NOT** execute — this is always blocked
2. Ask specifically what they mean
3. Present curated options based on actual scan results
4. Let them choose specific categories, not "everything"

### Rule 9: Honor "Don't Touch It"

If the user says "don't delete that file" or "find another way":
1. Immediately stop — do not proceed with deletion
2. Log the decision
3. Find alternatives: rename, deprecate, refactor around, ignore
4. Present the alternative approach to the user

### Rule 10: ≤100MB Auto, >100MB Ask

- Files ≤ 100MB: auto-backup before delete (no extra question)
- Files > 100MB: ask the user "Do you want me to back this up before deleting?"

---

## Decision Flow

```
User message received OR new coding task starts
        │
        ▼
[CMD] Check safe-delete state (/safe-delete status)
        │
        ├── OFF → Skip to [2] (trigger detection only)
        │          Only activates if user says explicit trigger words
        │
        └── ON → Continue below
        │
        ▼
[0] Analyze plan: will deletion be needed?
        │ No
        ▼
    Normal response — but re-check if plan changes
        │ Yes / Uncertain
        ▼
[1] Offer sub-agent deletion watcher
        │
        ├── Yes → Deploy watcher → Execute task (watcher intercepts deletes)
        │
               └── No  → Enter manual safe-delete mode
                    │
                    ▼
               [2] Check semantic triggers (see `commands.md`)
                    │
                    ▼
               [3] "Is this actually a delete?"
                    │
                    ▼
               [3a] Git check — is file tracked? Unpushed changes? Dirty? (see `functions/fn-git-aware.md`)
                    │
                    ▼
               [3b] Process check — is file in use by running process? (see `functions/fn-process-aware.md`)
                    │
                    ▼
                [3c] Language check — import graph analysis (see `functions/fn-language-aware.md`)
                    │
                    ▼
                [3d] Integrity check — entry point? Only-of-kind? Migration chain? (see `functions/fn-integrity-guard.md`)
                    │
                    ▼
                [3e] CI mode check — headless environment? (see `functions/fn-ci-cd.md`)
                    │
                    ▼
                [3f] Graphify check — dep graph available? Credit estimate? Install or CodeFlow?
                     (see `functions/fn-graphify-awareness.md`)
                    │
                    ▼
                 [3g] Skill integration gate — leverage other skills for enriched context
                      (see `functions/fn-skill-integration.md`)
                      (GitHub URL + no graphify -> suggest CodeFlow at codeflow-five.vercel.app)
                     │
                     ▼
                 [3h] Lockfile integrity — manifest + lockfile check for managed dirs
                      `node_modules/`/`vendor/`/`packages/`/`target/`
                      (see `functions/fn-lockfile-integrity.md`)
                     │
                     ▼
                 [3i] Symlink guard — detect symlinks/hardlinks/junctions
                      (see `functions/fn-symlink-guard.md`)
                     │
                     ▼
                 [3j] Cloud sync guard — OneDrive/Dropbox/iCloud/GDrive detection
                      (see `functions/fn-cloud-sync.md`)
                     │
                     ▼
                 [4] Score risk (1-10) — context-aware + all guard modifiers (see `functions/fn-risk-scoring.md`)
                    │
                    ▼
               [5] "Does user understand scope?"
                    │
                    ▼
               [6] List safer alternatives
                    │
                    ▼
               [7] Present modal with 5 options (see `functions/fn-delete-modal.md`)
                    │
                    ▼
               [8] Execute chosen option
                    │
                    ▼
               [9] Verify + Audit (see `functions/fn-audit.md`)
```

---

## What This Looks Like In Practice

### Example 1: Coding task — refactor
```
User: "refactor auth.js into smaller modules"
Agent plan analysis: 3 new files, 1 old file to delete
Agent: "This task requires deleting auth.js after extracting its parts.
       Do you want a background watcher?" 
       → Yes → deploys watcher → executes refactor
       → Watcher intercepts "delete auth.js" → presents modal
       → User chooses "Backup then Recycle Bin"
```

### Example 2: Coding task — upgrade
```
User: "upgrade our project from webpack 4 to webpack 5"
Agent plan analysis: config files will change, old webpack config may need removal
Agent: "This upgrade may remove old config files. Deploy watcher?"
       → No → agent proceeds manually
       → Before deleting old config: "I need to remove webpack.old.config.js.
         Here are your options:" → presents modal
```

### Example 3: User refuses deletion
```
User: "delete node_modules and reinstall"
Agent: presents modal → Options: Recycle Bin / Backup+Delete / Permanent / Skip / Alternative
User: chooses "Alternative" → "Can you just reinstall without deleting?"
Agent: "I can rename node_modules to node_modules_old, then reinstall.
       If everything works, you can delete the old one later."
```

### Example 4: Large file concern
```
User: "delete this 2GB dataset"
Agent: presents modal → User chooses "Backup then Delete"
Agent: "This file is 2 GB (> 100 MB). Do you want me to back it up first?
       Backup may take a few minutes."
       → Yes → backup (zip) → Recycle Bin
       → No → log decision → Recycle Bin
```

---

## Do Not

- Do NOT start coding tasks without first checking if deletion is needed
- Do NOT delete without presenting the modal — always show all 5 options
- Do NOT interpret "just do it" as consent — safe-delete overrides urgency
- Do NOT skip the watcher offer — always ask before complex tasks
- Do NOT skip cognitive checks — run all three every time
- Do NOT let the user's frustration speed up the protocol
- Do NOT treat "delete everything" literally — block and refine
- Do NOT assume you know what "old", "temp", or "junk" means — ask
- Do NOT skip alternatives — always offer Recycle Bin first
- Do NOT promise recovery if using permanent delete
- Do NOT use `Remove-Item` by default — always `FileIO::DeleteFile` → Recycle Bin
- Do NOT auto-backup > 100MB files without asking
- Do NOT proceed when user says "don't touch it" — find another way
- Do NOT treat this file as optional — it defines the agent's behaviour for every interaction
