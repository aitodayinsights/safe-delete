# Function 04: Audit Logging & Deletion Diary

## Purpose

Maintain a permanent, tamper-evident record of every delete operation. This provides:
- **Accountability** — who approved what and when
- **Recovery trail** — where to find backups
- **Blocked operations** — what was prevented and why
- **Session diary** — running record of all work done

## Audit Log File

**Location:** `%USERPROFILE%\.opencode-trash\deletion-log.txt`

**Format:** Entries are appended; never overwritten. Each entry is a structured block.

### Entry Template (15+ Fields Required)

```
[TIMESTAMP] RESULT | Score: X/10
  Target: {full path}
  Type: {file/dir/database/batch/grouped}
  Size: {total size}
  User: {username}
  Environment: {dev/staging/production}
  Reason: {user-provided reason}
  Risk Factors: {list of factors that contributed to score}
  Backup: {path to backup, or "none"}
  Backup Type: {manifest/file-copy/zip/dump/encrypted}
  Backup Verified: {true/false}
  Safekeeper: {true/false}
  Recycled: {true/false}
  Permanent: {true/false}
  Git Status: {tracked/untracked/modified/clean}
  What Breaks: {summary of dependencies affected}
  Approvals: {single/double/triple/written}
  Delay Observed: {true/false}
  Aborted: {true/false}
  Abort Reason: {if aborted}
  Agent Action: {delete/blocked/alternative-used}

```

### Real Example Entries

```
[2026-05-22 14:30:00] EXECUTED | Score: 3/10
  Target: C:\project\src\temp\old-component.tsx
  Type: file
  Size: 24 KB
  User: devuser
  Environment: dev
  Reason: Orphaned component after rename to Navbar.tsx
  Risk Factors: git tracked (+1)
  Backup: C:\Users\devuser\.opencode-trash\2026-05-22_143000-manifest.txt
  Backup Type: manifest
  Backup Verified: true
  Safekeeper: true
  Recycled: true
  Permanent: false
  Git Status: tracked, clean, 2 commits
  What Breaks: nothing
  Approvals: single
  Delay Observed: true
  Aborted: false

[2026-05-22 15:00:00] BLOCKED | Score: 9/10
  Target: production_db.public.customers WHERE deleted_at IS NOT NULL
  Type: database
  Size: 412,709 rows (33% of table)
  User: devuser
  Environment: production
  Reason: "Clean up old customers" (vague)
  Risk Factors: database operation (+4), production env (+3), large dataset (+2), no index (+3)
  Backup: customers_bak_20260522 created, CSV export at backupDir/customers.csv
  Backup Type: sql-dump + csv
  Backup Verified: true
  Safekeeper: N/A
  Recycled: N/A
  Permanent: N/A
  Git Status: N/A
  What Breaks: 2,847 orphaned orders, 3 views, 1 FK dependency
  Approvals: N/A — blocked before approval
  Delay Observed: N/A
  Aborted: true
  Abort Reason: Production detected + 412K rows + 2847 active orders referencing deleted customers
  Agent Action: blocked — suggested archiving instead

[2026-05-22 16:00:00] ABORTED | Score: 8/10
  Target: .env.production
  Type: file
  Size: 1.2 KB
  User: devuser
  Environment: production
  Reason: Rotate Stripe API key
  Risk Factors: env file (+4), production path (+3)
  Backup: C:\Users\devuser\.opencode-trash\2026-05-22_160000-.env.production
  Backup Type: file-copy
  Backup Verified: true
  Safekeeper: true
  Recycled: N/A
  Permanent: N/A
  Git Status: untracked
  What Breaks: Stripe payments would stop working
  Approvals: first confirm given
  Delay Observed: true (15s of 30s)
  Aborted: true
  Abort Reason: User said "stop" during 30-second delay
  Agent Action: aborted — no deletion occurred, backup retained

[2026-05-26 11:22:13] EXECUTED | Score: 6/10
  Target: C:\Users\Uncod\.lmstudio\models\ (7.36 GB) + C:\Users\Uncod\...\anythingllm\storage\ (6.08 GB)
  Type: grouped (2 targets, 7 items)
  Size: 13.44 GB
  User: Uncod
  Environment: dev
  Reason: Free up C drive space — user selected from curated options
  Risk Factors: files >100MB (+3), modified <24h (+2), safe-to-clear modifier (cache+partial, -1)
  Backup: C:\Users\Uncod\.opencode-trash\2026-05-26_112213-manifest.txt
  Backup Type: manifest (should have been zip for risk ≥ 6)
  Backup Verified: false (no backup created — GAP)
  Safekeeper: true
  Recycled: true
  Permanent: false
  Git Status: untracked
  What Breaks: LM Studio and AnythingLLM need to re-download models
  Approvals: single (should have been double for risk 6 — GAP)
  Delay Observed: false (should have been 10s — GAP)
  Aborted: false
```

## Deletion Diary (Session-Level)

In addition to the permanent log, the agent maintains a session diary:

```powershell
$sessionId = Get-Date -Format "yyyy-MM-dd_HHmmss"
$diaryPath = "$env:USERPROFILE\.opencode-trash\session-$sessionId-diary.txt"

function Write-DiaryEntry {
    param($Action, $Target, $Risk, $Result)
    $entry = "[$(Get-Date -Format 'HH:mm:ss')] $Action | Risk: $Risk | Target: $Target | Result: $Result"
    Add-Content -Path $diaryPath -Value $entry
}

# Example entries:
# [14:30:00] DELETE | Risk: 3 | Target: old-component.tsx | Result: EXECUTED → Recycle Bin
# [15:00:00] DELETE | Risk: 9 | Target: customers table (412K rows) | Result: BLOCKED → Archive alternative used
# [16:00:00] DELETE | Risk: 8 | Target: .env.production | Result: ABORTED → User stopped
# [11:22:13] DELETE | Risk: 6 | Target: AI models (13.44 GB grouped) | Result: EXECUTED → Recycle Bin (GAPS: single confirm, no delay, no zip backup)
```

## Permanent Deletions Log (Separate)

**Location:** `%USERPROFILE%\.opencode-trash\permanent-deletions.log`

This is a separate, harder-to-miss log for permanent deletions only. Format includes the user's written reason.

```
=== PERMANENT DELETION LOG ===
Date: 2026-05-22 16:30:00
User: devuser
Target: C:\project\secrets\temp-key.pem
Risk Score: 9/10
Written Reason: "Key was rotated — new key deployed, old key revoked in AWS, no services depend on it"
Backup: C:\Users\devuser\.opencode-trash\perm-2026-05-22_163000-temp-key.pem.zip
Approvals: triple confirm + written reason + 60s delay
Delay Observed: true
Safekeeper: true
```

## Audit Log Entry Generator

```powershell
function Write-AuditLog {
    param(
        [string]$Result,          # EXECUTED, BLOCKED, ABORTED, CANCELLED, INSTANT
        [int]$RiskScore,
        [string]$Target,
        [string]$Type,
        [string]$Size,
        [string]$User = $env:USERNAME,
        [string]$Environment = "dev",
        [string]$Reason,
        [string]$RiskFactors,
        [string]$Backup,
        [string]$BackupType,
        [bool]$BackupVerified,
        [bool]$Safekeeper,
        [bool]$Recycled,
        [bool]$Permanent = $false,
        [string]$GitStatus = "N/A",
        [string]$WhatBreaks = "none",
        [string]$Approvals,
        [bool]$DelayObserved = $false,
        [bool]$Aborted = $false,
        [string]$AbortReason = "",
        [string]$AgentAction = "delete"
    )

    $entry = @"
[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Result | Score: $RiskScore/10
  Target: $Target
  Type: $Type
  Size: $Size
  User: $User
  Environment: $Environment
  Reason: $Reason
  Risk Factors: $RiskFactors
  Backup: $Backup
  Backup Type: $BackupType
  Backup Verified: $BackupVerified
  Safekeeper: $Safekeeper
  Recycled: $Recycled
  Permanent: $Permanent
  Git Status: $GitStatus
  What Breaks: $WhatBreaks
  Approvals: $Approvals
  Delay Observed: $DelayObserved
  Aborted: $Aborted
  Abort Reason: $AbortReason
  Agent Action: $AgentAction

"@
    $logPath = "$env:USERPROFILE\.opencode-trash\deletion-log.txt"
    $logDir = Split-Path $logPath -Parent
    if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    Add-Content -Path $logPath -Value $entry
}
```

## Do Not

- Do NOT skip the audit log — it must be written for every operation
- Do NOT overwrite existing log entries — always append
- Do NOT log secrets, passwords, or sensitive data in plaintext
- Do NOT forget to log BLOCKED and ABORTED operations — these are valuable
- Do NOT store the log in the project directory — use `~/.opencode-trash/`
- Do NOT use fewer than 15 fields — the full template matters for recovery
- Do NOT skip logging the "What breaks" analysis — it's critical for post-mortem
- Do NOT skip the session diary — it provides context across multiple operations
- Do NOT forget to log GAPS in your own protocol compliance (as shown in the example) — self-audit builds trust
