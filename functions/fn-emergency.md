# Function 09: Emergency Abort

## Purpose

Provide an immediate kill switch if the user says "stop", "wait", "cancel", "abort", "undo", or "don't delete that" at any point during the protocol.

## Abort Levels

| Level | Trigger | Action |
|-------|---------|--------|
| **Soft abort** | User says "wait/cancel" before execution | Stop the protocol. No delete occurred. Nothing to undo. |
| **Hard abort** | User says "stop" during delay period (30s/60s) | Halt countdown. No execute. |
| **Emergency abort** | User says "abort/stop" during or after execution | Rollback if possible. Issue ROLLBACK for DB transactions. Provide recovery instructions for files already deleted. |

## Implementation

### Before Execution (Soft Abort)

```powershell
if ($userSaysCancel) {
    Write-Host "✓ Delete cancelled. No action taken."
    # Log the cancellation
    Add-Content -Path "$env:USERPROFILE\.opencode-trash\deletion-log.txt" @"
[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] CANCELLED | Score: $riskScore/10
  Target: $targetPath
  Reason: User cancelled during confirmation
  Agent Action: none — protocol stopped before execution
"@
    return
}
```

### During Delay Countdown (Hard Abort)

The 60-second/30-second delay window is the best chance for the user to reconsider. During this window, the agent should be responsive to any abort command.

```powershell
for ($i = 60; $i -gt 0; $i--) {
    Write-Host "`r⚠ $i seconds until delete. Say 'stop' to abort..." -NoNewline
    # In practice, the agent listens for user input between actions
    # If user interjects with "stop", the agent stops
    Start-Sleep -Seconds 1
    if ($userSaidStop) { break }
}
```

### After Execution (Emergency Abort)

If a file has already been deleted and the user wants it back:

```powershell
# File was sent to Recycle Bin:
Write-Host "⚠ File was sent to Recycle Bin. To restore:"
Write-Host "  1. Run: Start-Process shell:RecycleBinFolder"
Write-Host "  2. Find the file (sorted by date deleted)"
Write-Host "  3. Right-click → Restore"
Write-Host "  4. Or run this restore command:"
Write-Host "     Copy-Item '$backupPath' '$originalPath'"
```

### For Database Operations

```sql
-- If within a transaction:
ROLLBACK;

-- If already committed (no transaction):
-- Restore from backup table:
INSERT INTO original_table SELECT * FROM backup_table_YYYYMMDD;

-- Restore from CSV:
\COPY original_table FROM 'backup.csv' CSV HEADER;
```

## Abort Audit Log

Every abort is logged with the reason:

```
[2026-05-22 15:05:00] ABORTED | Score: 8/10
  Target: .env.production
  Reason: User said "wait I need to check something"
  Agent Action: aborted during 30s delay — no deletion occurred
```

## Do Not

- Do NOT ignore user saying "stop" or "wait" — halt immediately
- Do NOT restart the countdown after abort unless user explicitly asks
- Do NOT forget to log aborts — they're valuable for future decisions
- Do NOT delete the backup on abort — user may need it
