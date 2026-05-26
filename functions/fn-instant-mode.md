# Function Extra: Instant Mode — Conscious Fast Delete

## Purpose

Bypass all safety steps when the user **knows** they want something gone and values speed over safety. Triggered by a `/instant` prefix in the delete request. No backups, no Recycle Bin, no safekeeper, no confirmations beyond a single warning — the file is gone immediately.

## How It Works

```
User: "/instant delete dist/"
         ↓
Agent shows single warning: "⚠️ INSTANT MODE — no backup, no recovery"
         ↓
User confirms: "yes, delete permanently"
         ↓
File deleted immediately (Remove-Item -Force)
Safekeeper skipped
Recycle Bin skipped
Backup skipped
         ↓
Audit logged with [INSTANT] tag
Nothing can undo it
```

## Trigger

The user must explicitly mark the request with `/instant` at the beginning:

- `"/instant delete the node_modules folder"` — valid
- `"/instant remove all .tmp files in src/"` — valid
- `"/instant permanently delete .env.production"` — valid
- `"delete dist/"` — NOT instant (normal safe-delete workflow)
- `"/instant"` alone with no target — invalid, ask what to delete

The agent checks the first word of the user's request. If it's `/instant`, the instant protocol activates.

## What Gets Bypassed

| Normal Step | In Instant Mode |
|-------------|-----------------|
| Risk scoring | Skipped (shown for info only, no gating) |
| Target inspection | ⚠️ 1-line summary only |
| Dependency analysis | Skipped |
| "What could go wrong" | Skipped |
| Backup (to `.opencode-trash`) | Skipped |
| Safekeeper (hidden backup) | Skipped |
| Confirmation matrix | **Single warning** replaces all |
| Recycle Bin | Skipped (`Remove-Item -Force`, not `FileIO.DeleteFile`) |
| Verification prompt | Skipped |
| **Still happens:** Audit log | ✅ Always logged |
| **Still happens:** Deletion diary | ✅ Always logged |

## The Warning

Before executing, show this **exact** warning block. The user must respond with an affirmative confirmation.

```markdown
╔══════════════════════════════════════════════════════════╗
║              ⚠️  INSTANT DELETE MODE                     ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  Target: src/old-module/                                 ║
║  Size:   2.4 MB (47 files)                               ║
║  Risk:   3 / 10 (low)                                    ║
║                                                          ║
║  • NO backup will be created                             ║
║  • NO Recycle Bin — file is GONE forever                 ║
║  • NO safekeeper hidden copy                             ║
║  • NO undo possible                                      ║
║                                                          ║
║  Type "yes, delete permanently" to confirm               ║
║  Type anything else (or just press Enter) to cancel      ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
```

Only these exact phrases confirm:
- `"yes, delete permanently"`
- `"yes"` (after the warning has been fully shown)

Anything else cancels the operation.

## Risk Gates for Instant Mode

Even in instant mode, some operations are too dangerous:

| Risk | Instant Mode Behaviour |
|------|----------------------|
| 1–5 (Low) | Bypass all safety with single warning |
| 6–7 (Medium) | Bypass all safety with single warning + show risk score |
| 8–9 (High) | Warning + must type "I UNDERSTAND THE RISK" + still bypasses |
| 10 (Catastrophic) | **BLOCKED** — /instant cannot override catastrophic risk. Use normal safe-delete protocol |

For critical/catastrophic targets, the agent must refuse:

```markdown
╔══════════════════════════════════════════════════════════╗
║           🚫  INSTANT MODE BLOCKED                       ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  Target: .env.production                                 ║
║  Risk:   10 / 10 (catastrophic)                          ║
║                                                          ║
║  /instant mode cannot be used for catastrophic-risk      ║
║  operations. Use the normal safe-delete workflow with    ║
║  all safety checks enabled.                              ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
```

## Implementation

```powershell
function Invoke-InstantDelete {
    param(
        [string]$TargetPath,
        [bool]$IsDirectory = $false
    )

    # 1. Calculate risk (for display and gating)
    $riskScore = Get-DeleteRiskScore -Path $TargetPath

    # 2. Block catastrophic risk (score = 10)
    if ($riskScore -ge 10) {
        Write-Host "🚫 /instant blocked — catastrophic risk. Use normal safe-delete protocol."
        return $false
    }

    # 3. Show warning
    $item = Get-Item -LiteralPath $TargetPath -EA 0
    $sizeInfo = if ($IsDirectory) {
        "$((Get-ChildItem $TargetPath -Recurse -File | Measure-Object Length -Sum).Sum / 1MB -as [int]) MB ($((Get-ChildItem $TargetPath -Recurse | Measure-Object).Count) items)"
    } else { "$($item.Length / 1KB -as [int]) KB" }

    $warning = @"

╔══════════════════════════════════════════════════════════╗
║              ⚠️  INSTANT DELETE MODE                     ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  Target: $TargetPath
║  Size:   $sizeInfo
║  Risk:   $riskScore / 10 $(if ($riskScore -ge 8) { "(HIGH)" } else { "(low)" })
║                                                          ║
║  • NO backup will be created                             ║
║  • NO Recycle Bin — file is GONE forever                 ║
║  • NO safekeeper hidden copy                             ║
║  • NO undo possible                                      ║
║                                                          ║
$(if ($riskScore -ge 8) {
"║  ⚠️  HIGH-RISK: Type EXACTLY: I UNDERSTAND THE RISK      ║"
} else {
"║  Type "yes, delete permanently" to confirm               ║"
"║  Type anything else (or press Enter) to cancel           ║"
})
║                                                          ║
╚══════════════════════════════════════════════════════════╝
"@

    Write-Host $warning

    # 4. Get confirmation
    $confirmation = Read-Host "> "

    if ($riskScore -ge 8) {
        if ($confirmation -ne "I UNDERSTAND THE RISK") {
            Write-Host "✗ Cancelled. No changes made."
            return $false
        }
    } else {
        if ($confirmation -notin @("yes, delete permanently", "yes")) {
            Write-Host "✗ Cancelled. No changes made."
            return $false
        }
    }

    # 5. Execute permanent delete
    if ($IsDirectory) {
        Remove-Item -LiteralPath $TargetPath -Recurse -Force
    } else {
        Remove-Item -LiteralPath $TargetPath -Force
    }

    # 6. Audit log
    $logPath = "$env:USERPROFILE\.opencode-trash\deletion-log.txt"
    $logDir = Split-Path $logPath -Parent
    if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

    $logEntry = @"
[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [INSTANT] PERMANENT DELETE
  Target: $TargetPath
  Type: $(if ($IsDirectory) { 'directory' } else { 'file' })
  Size: $sizeInfo
  Risk: $riskScore / 10
  User: conscious /instant mode
  Backup: NONE (bypassed)
  Recovery: IMPOSSIBLE
"@
    $logEntry | Add-Content $logPath

    Write-Host "✓ Permanently deleted: $TargetPath"
    return $true
}
```

## Audit

All `/instant` deletes are logged to the audit log with an `[INSTANT]` tag for clear traceability:

```
[2026-05-22 14:30:00] [INSTANT] PERMANENT DELETE
  Target: W:\AI work 2026\node_modules
  Size: 234 MB (28471 items)
  Risk: 2 / 10 (low)
  User: conscious /instant mode
  Backup: NONE (bypassed)
  Recovery: IMPOSSIBLE
```

There is NO recovery path. The audit entry is the only record that the file ever existed.

## Do Not

- Do NOT activate `/instant` unless the user explicitly starts the request with `/instant`
- Do NOT interpret "just delete it" or "I'm sure" as instant mode — only `/instant` triggers it
- Do NOT skip the warning — always show the full warning box
- Do NOT accept casual confirmation — must type exactly as specified
- Do NOT allow `/instant` on catastrophic risk (score 10) — block always
- Do NOT allow `/instant` on production databases (always requires full safe-delete)
- Do NOT create any backup, copy, or safekeeper entry during instant mode
- Do NOT promise recovery — there is none
- Do NOT skip the audit log — this is the ONLY record of what happened
