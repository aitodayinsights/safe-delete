# Function 06: Delete Modal — Interactive Pop-Up

## Purpose

Present a structured, interactive modal/pop-up to the user before ANY delete operation. The modal gives the user full control over how deletion is handled — including the option to refuse entirely.

---

## Command Status Check (Gate)

Before presenting the modal, check the current safe-delete state:

```powershell
$safeDeleteMode = $env:SAFE_DELETE
if (-not $safeDeleteMode) {
    # Check agent config file
    $configPath = "$env:USERPROFILE\.config\opencode\AGENTS.md"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw
        if ($config -match 'safe_delete:\s*(\w+)') { $safeDeleteMode = $Matches[1] }
    }
}

switch ($safeDeleteMode) {
    "off" {
        # OFF: Only show modal if triggered by explicit delete command
        # If the user typed "delete X" or used a semantic trigger: show modal normally
        # If this is a coding side-effect: skip modal, proceed with Recycle Bin default
        if (-not $triggeredByExplicitCommand) {
            Write-Warning "[safe-delete OFF] Skipping modal (coding side-effect). Using Recycle Bin."
            return "RECYCLE_SILENT"
        }
    }
    "watcher" {
        # WATCHER: Ensure watcher is running before modal
        if (-not $WatcherRunning) { Start-WatcherSubAgent }
    }
    default {
        # ON: Full modal as designed below
    }
}
```

**This check ensures:**
- When OFF: Modal only appears for explicit delete commands, not for coding side-effects
- When WATCHER: Modal always passes through the watcher sub-agent
- When ON: Full modal as designed

---

## Modal Template

```
┌──────────────────────────────────────────────────────────────────┐
│ ⚠ DELETE CONFIRMATION REQUIRED                                   │
│                                                                  │
│ Target:  {full file/directory path}                              │
│ Type:    {file / directory / database / batch}                   │
│ Size:    {total size}                                            │
│ Risk:    {score}/10 ({label})                                     │
│                                                                  │
│ What breaks if this is deleted:                                   │
│   • {dependency 1}                                                │
│   • {dependency 2}                                                │
│   • {running service}                                             │
│                                                                  │
│ Recovery plan:                                                    │
│   • Recycle Bin restore (if option 1 or 2 chosen)                 │
│   • Backup at: {path}                                             │
│   • Rollback script: {script path}                                │
│                                                                  │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ How would you like to proceed?                               │ │
│ │                                                              │ │
│ │ [1] 🗑 Move to Recycle Bin (temp — recoverable)              │ │
│ │ [2] 💾 Backup then Delete (creates backup first)             │ │
│ │ [3] ⚡ Permanent Delete (⚠ irreversible)                     │ │
│ │ [4] ✋ Skip — Don't touch this                              │ │
│ │ [5] 💡 Find Alternative — suggest another approach           │ │
│ │                                                              │ │
│ │ Or type your preference: ________________________________    │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│ [Confirm]  [Cancel]                                              │
└──────────────────────────────────────────────────────────────────┘
```

---

## Option Logic

### Option 1: Move to Recycle Bin (DEFAULT)
- **When to default**: Always, unless risk ≥ 8
- **What happens**: Files go to `FileIO::DeleteFile('SendToRecycleBin')`
- **Recovery**: Full Recycle Bin restore
- **Extra step for > 100MB**: Ask "This is > 100MB. Take backup first?"

### Option 2: Backup then Delete
- **When to default**: Risk ≥ 6, or user seemed hesitant, or ≤ 100MB automatic backup preferred
- **What happens**:
  - ≤ 100 MB: Auto-backup (zip if ≥ 6, file copy if 4–5, manifest if < 4)
  - > 100 MB: Ask "This file is X MB. Do you want me to back it up first?"
    - If Yes → backup + Recycle Bin
    - If No → log decision (user declined backup) → Recycle Bin
- **Recovery**: Restore from backup file + Recycle Bin

### Option 3: Permanent Delete (GUARDED)
- **When to default**: Never
- **What happens**: See `fn-permanent-delete.md` — triple confirm + written reason + delay
- **Risk 10**: BLOCKED — user must manually verify
- **Recovery**: None — this is irreversible

### Option 4: Skip — Don't Touch
- **When to default**: Only if user previously said "don't delete this"
- **What happens**: Nothing. File stays. Decision logged.
- **Agent behavior**: Stop and find an alternative approach. Log to deletion diary as "SKIPPED".
- **Options after skip**:
  - Rename the file instead
  - Deprecate it (add deprecation notice, keep file)
  - Refactor the code to work without deleting
  - Add to `.gitignore` if generated
  - Move to a separate archive directory

### Option 5: Find Alternative
- **When to default**: User seems unsure, or the deletion seems avoidable
- **What happens**: Agent suggests 2–3 alternatives
- **Alternative suggestions**:
  1. **Rename** — rename file to `.old` or `.bak` instead of deleting
  2. **Deprecate** — add a deprecation warning, keep the file for reference
  3. **Archive** — move to an `archive/` directory within the project
  4. **Refactor around** — modify the code to not depend on this file
  5. **Ignore** — add to `.gitignore` if it's a generated file
  6. **Delay** — keep for now, set a reminder to delete later
- **User can choose one alternative or go back to the modal**

---

## Question Tool Implementation

When the platform supports structured questions:

```powershell
function Show-DeleteModal {
    param(
        [string]$Target,
        [string]$TargetType,
        [string]$Size,
        [int]$RiskScore,
        [string]$RiskLabel,
        [string[]]$WhatBreaks,
        [string]$RecoveryPlan,
        [bool]$IsLargeFile = $false  # > 100MB
    )

    $description = @"
**Target:** $Target
**Type:** $TargetType
**Size:** $Size
**Risk:** $RiskScore/10 ($RiskLabel)

**What breaks if deleted:**
$(($WhatBreaks | ForEach-Object { "- $_" }) -join "`n")

**Recovery:** $RecoveryPlan
"@

    # Present modal via question tool
    $result = question @{
        questions = @(
            @{
                header = "⚠ Delete Confirmation Required"
                question = $description
                options = @(
                    @{ label = "Recycle Bin"; description = "Move to Recycle Bin (recoverable)" }
                    @{ label = "Backup then Delete"; description = "Backup first, then Recycle Bin" }
                    @{ label = "Permanent Delete"; description = "Irreversible — use with extreme caution" }
                    @{ label = "Skip"; description = "Don't touch this file" }
                    @{ label = "Find Alternative"; description = "Suggest another approach" }
                )
            }
        )
    }

    # Process the user's choice
    switch ($result) {
        "Recycle Bin" { return "RECYCLE" }
        "Backup then Delete" { return "BACKUP_THEN_DELETE" }
        "Permanent Delete" { return "PERMANENT" }
        "Skip" { return "SKIP" }
        "Find Alternative" { return "ALTERNATIVE" }
    }
}
```

---

## Large File Handling (> 100 MB)

When user chooses Option 1 or 2 and file > 100 MB:

```powershell
function Confirm-LargeFileBackup {
    param([string]$Path, [long]$SizeMB)

    $result = question @{
        questions = @(
            @{
                header = "Large File: Backup Required?"
                question = "This file/folder is ${SizeMB}MB (> 100 MB).`n`nDo you want me to back it up before deleting?`n`nBackup may take some time."
                options = @(
                    @{ label = "Yes, backup first"; description = "Create backup, then delete" }
                    @{ label = "No, just delete"; description = "Delete without backup (your choice)" }
                )
            }
        )
    }
    return ($result -eq "Yes, backup first")
}
```

---

## Multi-Target Modal

When deleting multiple targets (grouped operation):

```
┌──────────────────────────────────────────────────────────────────┐
│ ⚠ GROUPED DELETE — 5 Targets                                     │
│                                                                  │
│ # │ Target                          │ Size    │ Risk             │
│ ──┼─────────────────────────────────┼─────────┼──────────────────│
│ 1 │ node_modules/                    │ 240 MB  │ 4/10 (Medium)    │
│ 2 │ .next/cache/                     │ 85 MB   │ 3/10 (Low)       │
│ 3 │ dist/                            │ 120 MB  │ 4/10 (Medium)    │
│ 4 │ old-config.js                    │ 12 KB   │ 3/10 (Low)       │
│ 5 │ .env.staging                     │ 1.2 KB  │ 8/10 (Critical)  │
│                                                                  │
│ Operating risk: 8/10 (Critical) — using highest target risk      │
│                                                                  │
│ [1] Move All to Recycle Bin  [2] Backup All then Delete          │
│ [3] Skip All                [4] Choose per target                │
│                                                                  │
│ [Confirm]  [Cancel]                                              │
└──────────────────────────────────────────────────────────────────┘
```

**Choose per target (Option 4):** Lists each target individually with its own 5-option modal.

---

## "What Could Go Wrong" Integration

For risk ≥ 6, embed the WCGW analysis directly in the modal description:

```
┌──────────────────────────────────────────────────────────────────┐
│ ⚠ DELETE — What Could Go Wrong                                    │
│                                                                  │
│ Scenario                    │ Impact                              │
│ ────────────────────────────┼──────────────────────────────────── │
│ Immediate failure           │ Service X will crash on next restart│
│ Silent corruption           │ Module Y imports this file silently │
│ Data loss                   │ User preferences stored here        │
│ Security incident           │ Cert revocation may cause outage    │
│ Regret                      │ Used by scheduled job Z             │
│                                                                  │
│ [1] Recycle Bin  [2] Backup+Delete  [3] Skip  [4] Alternative    │
└──────────────────────────────────────────────────────────────────┘
```

---

## Timeout Behavior

If the user does not respond to the modal within 5 minutes:
- Revert to default action (Recycle Bin / Skip)
- Log as "TIMEOUT — default action taken"
- Ask: "You didn't respond — I chose the safest option ({option}). Is that OK?"

---

## Do Not

- Do NOT present a modal without all 5 options — the user needs full choice
- Do NOT make Permanent Delete the default — never
- Do NOT skip the large-file backup question (> 100 MB)
- Do NOT proceed when user chooses "Skip" — respect it
- Do NOT suggest weak alternatives for "Find Alternative" — offer real, actionable options
- Do NOT bury the "Cancel" option — it should be clearly visible
- Do NOT combine multiple independent targets into one modal without showing each individually
- Do NOT skip the WCGW analysis in the modal for risk ≥ 6
- Do NOT auto-confirm on timeout — always default to the safest option
- Do NOT hide the recovery plan — the user needs to know how to undo this
