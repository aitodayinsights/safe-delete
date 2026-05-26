# Usage Guide

## Everyday Usage

Safe-Delete is designed to be mostly invisible. It activates when needed and stays out of the way otherwise.

### Normal Flow

```
1. You ask your agent to do something
2. Agent works normally — reads files, modifies code, creates new files
3. If the plan includes deleting ANYTHING — safe-delete activates
4. You see a modal with options
5. You choose how to handle it
6. Agent continues with your choice
```

### Slash Commands

```
/safe-delete         → Show current status
/safe-delete on      → Enable full protection
/safe-delete off     → Trigger-only mode (no proactive watching)
/safe-delete watcher → Deploy background deletion watcher
/safe-delete status  → Extended status + activity log
```

### When to Use /safe-delete off

```
✓ Data exploration (read-only)
✓ Code review (no modification)
✓ Series of intentional, user-directed deletions
✓ When the always-bound check slows down your workflow

Remember: OFF doesn't disable all protection — trigger words still work.
```

---

## Scenarios

### Scenario 1: Refactoring Code

```
You: "Split auth.js into smaller modules"

Agent: "This task requires:
  - Create auth-login.js
  - Create auth-signup.js
  - Create auth-middleware.js
  - Delete auth.js (⚠ original file)

  Deploy background watcher? [Yes / No]"

You: "Yes"

[Agent works — creates the 3 new files]
[Agent tries to delete auth.js → watcher intercepts]

┌─────────────────────────────────────────────┐
│ ⚠ DELETE: auth.js                           │
│ Risk: 6 (imported by 4 files)               │
│                                             │
│ [1] Recycle Bin   [2] Backup+Delete         │
│ [3] Permanent     [4] Skip  [5] Alternative │
└─────────────────────────────────────────────┘

You: "1"

✓ auth.js moved to Recycle Bin
✓ All 4 importers still work (imports resolved)
✓ You can restore any time
```

### Scenario 2: Database Migration

```
You: "Roll back the last migration"

Agent: ⚠ This involves deleting migration 004_add_indexes.sql
        ⚠ Other migrations depend on 004
        ⚠ Migration is already applied

┌─────────────────────────────────────────────┐
│ ⚠ INTEGRITY GUARD: Migration File           │
│                                             │
│ [1] Create reversal migration  ✓ safest     │
│ [2] Skip — keep the file                    │
│ [3] Force delete (⚠ breaks chain)          │
└─────────────────────────────────────────────┘

You: "1"

✓ Created: db/migrations/005_reverse_004.sql
✓ Old migration preserved
✓ Chain stays valid
```

### Scenario 3: CI/CD Pipeline

```
[GitHub Actions runs]
[Agent runs cleanup as part of CI]

[CI mode detected — no terminal]
[SAFE_DELETE_CI=true not set]

[CI] [safe-delete] ACTION=backup  TARGET="dist/" RISK=6
[CI] [safe-delete] ACTION=block   TARGET=".env.prod" RISK=9
  → BLOCKED: risk ≥ 8 in CI mode
  → Set SAFE_DELETE_CI=true to allow risk 8-9

[Pipeline continues without error because continue-on-error: true]
[No files were deleted — restore from backup if needed]
```

### Scenario 4: Large File Cleanup

```
You: "Free up some disk space"

Agent: [Scans disk usage]
  C:\Users\You\Downloads\old-dataset.csv    2.1 GB
  C:\Users\You\AppData\Local\Temp\*        450 MB
  C:\Projects\old-project\node_modules\    340 MB

┌─────────────────────────────────────────────┐
│ ⚠ 3 TARGETS FOUND                          │
│                                             │
│ [1] Recycle Bin All    [2] Backup+Delete    │
│ [3] Per target         [4] Skip All         │
└─────────────────────────────────────────────┘

You: "Let's see per target"

  Target 1: old-dataset.csv (2.1 GB)
    → >100MB: "Backup first?" [Yes/No]
    → No → Recycle Bin

  Target 2: Temp (450 MB)
    → Auto → Recycle Bin

  Target 3: node_modules (340 MB)
    → [1] Recycle Bin  [2] Alternative: rename
    → You choose Alternative → renamed to node_modules_old
```

### Scenario 5: Agent Tries to Delete Git History

```
You: "Clean up the project"

Agent: [Thinks about deleting .git/]

┌─────────────────────────────────────────────┐
│ ⚠ GIT-AWARE: .git/                          │
│                                             │
│ ⚠ BLOCKED: This is a git directory          │
│                                             │
│ Deleting .git/ will:                         │
│   • Remove all version history               │
│   • Break all branches                      │
│   • Cannot be undone                         │
│                                             │
│ [1] Skip — keep .git/         (recommended) │
│ [2] Archive .git/ instead                   │
│ [3] Find Alternative — shallow clone?       │
└─────────────────────────────────────────────┘

You: "I just meant clean up build artifacts"

Agent: ✓ Understood. Scanning for build artifacts instead...
  dist/         120 MB ✓ Recycle Bin
  .next/        85 MB  ✓ Recycle Bin
  *.log         12 MB  ✓ Recycle Bin
```

---

## Recovery

### From Recycle Bin

```bash
# Windows
Start-Process shell:RecycleBinFolder

# macOS
open ~/.local/share/Trash/

# Linux
ls -la ~/.local/share/Trash/files/
```

### From Backup

```powershell
# List recent backups
Get-ChildItem ~/.opencode-trash/backups/ | Sort-Object LastWriteTime -Descending

# Restore specific backup
Copy-Item ~/.opencode-trash/backups/20260526_auth_js_bak/auth.js ./src/auth.js
```

### From Git

```bash
# Restore a deleted file from git
git restore --source=HEAD~1 path/to/file.ext

# Or checkout
git checkout HEAD~1 -- path/to/file.ext
```

### From Safekeeper (Emergency Only)

```powershell
# List safekeeper contents
Get-ChildItem "$env:LOCALAPPDATA\.opencode-safekeeper\" -Recurse

# Restore from safekeeper
# (Look for path matching your file in manifest.json)
```

---

## Best Practices

1. **Leave safe-delete ON** — The default is designed for safety. Only turn it off for specific read-only tasks.

2. **Use the watcher for complex refactors** — It catches deletions you might not expect as part of a larger change.

3. **Let it backup >100MB files** — The extra minute of backup time is worth not losing 2GB of work.

4. **Use Skip or Alternative** — These aren't "failures." They're intelligent ways to avoid unnecessary deletion.

5. **Check the audit log** — `~/.opencode-trash/deletion-log.txt` contains everything safe-delete has done.

6. **Keep the safekeeper enabled** — It's stored locally and auto-cleaned after 48h. It's your last resort.
