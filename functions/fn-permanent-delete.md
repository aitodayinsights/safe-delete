# Function 06: Permanent Delete (Triple-Guarded)

## Purpose

Handle the rare case where permanent deletion is genuinely needed (secure data, secrets rotation, GDPR compliance). This is **never** the default — it requires maximum safeguards.

## Protocol (Required — All Steps)

This is a **10-step** protocol that must complete before any permanent delete executes.

```
[1. Verify need] → [2. Score risk] → [3. Alert user] → [4. Backup]
→ [5. First confirm] → [6. Impact review] → [7. Second confirm]
→ [8. Written reason] → [9. 60s delay] → [10. Execute]
```

### Step 1: Verify Need

Is permanent deletion genuinely required? Ask:

- Could this go to Recycle Bin instead? (Every OS has Recycle Bin/Trash)
- Could this be archived instead?
- Could this be encrypted instead of destroyed?
- Is there a compliance/legal requirement for secure deletion?

**If any alternative works → use it. Permanent delete is the LAST resort.**

### Step 2: Score Risk

Use `fn-risk-scoring.md`. Any permanent delete automatically starts at risk 8.

Additional factors for permanent delete:
- `+2` if the data contains PII (personally identifiable information)
- `+2` if secure wipe is required (beyond simple file delete)
- `+1` if the file has never been backed up

### Step 3: Alert User

```markdown
## ⚠ PERMANENT DELETE — This cannot be undone via Recycle Bin

You are about to permanently delete:
  {path} ({size}, modified {date})

This file will NOT go to Recycle Bin. It will be GONE.
{list consequences}

### Safer alternatives:
- [ ] Send to Recycle Bin instead (recoverable)
- [ ] Archive to .trash/ instead
- [ ] Rename to .old instead
- [ ] Encrypt instead of delete
- [ ] Proceed with permanent delete (requires 2 more confirmations + written reason)
```

### Step 4: Backup

```powershell
$backup = Backup-File($path)
# For permanent deletes, also create a zip archive:
$zipBackup = "$env:USERPROFILE\.opencode-trash\perm-$(Get-Date -Format 'yyyy-MM-dd_HHmmss')-$(Split-Path $path -Leaf).zip"
Compress-Archive -LiteralPath $path -DestinationPath $zipBackup
```

### Step 5: First Confirm

Present the `question` tool with clear options. **User must explicitly select "Permanent delete".**

### Step 6: Impact Review

Generate full "What could go wrong" analysis:

| Scenario | Outcome |
|----------|---------|
| User needs this file tomorrow | Gone. No recovery from Recycle Bin. |
| Compliance audit finds missing records | No paper trail, no recovery. |
| Data was referenced elsewhere | Broken references, missing assets. |

### Step 7: Second Confirm

Second `question` — identical to first, must match.

### Step 8: Written Reason

```markdown
### WRITTEN REASON REQUIRED

To proceed with permanent deletion, please write 1-2 sentences explaining:
1. WHY permanent deletion is necessary (not Recycle Bin)
2. WHAT data is being destroyed
3. HOW you will recover if this was a mistake

Your reason: _______
```

The agent logs this reason to the audit trail.

### Step 9: 60-Second Delay

```powershell
Write-Host "⚠ PERMANENT DELETE in 60 seconds. Press Ctrl+C to cancel."
for ($i = 60; $i -gt 0; $i--) {
    Write-Host "`r$i seconds remaining..." -NoNewline
    Start-Sleep -Seconds 1
}
```

### Step 10: Execute

```powershell
Remove-Item -LiteralPath $path -Force

# Log to permanent delete log (separate from Recycle Bin log)
$log = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] PERMANENT DELETE`n"
$log += "  Target: $path`n"
$log += "  User: $env:USERNAME`n"
$log += "  Reason: $userWrittenReason`n"
$log += "  Backup: $backup`n"
$log += "  Double-confirmed: true`n"
$log += "  60s delay observed: true`n"
$log += "`n"
Add-Content -Path "$env:USERPROFILE\.opencode-trash\permanent-deletions.log" -Value $log
```

## Secure Wipe (Beyond File Delete)

For sensitive data, simple `Remove-Item` is not enough (data is still on disk):

```powershell
# For SSDs: use cipher or built-in secure erase
cipher /w:C:\path\to\directory

# For individual files:
# (PowerShell doesn't have built-in secure wipe; use sdelete from Sysinternals)
# sdelete -p 3 file.ext   (3-pass overwrite)
```

## Do Not

- Do NOT accept "just delete it" — permanent is never casual
- Do NOT skip any of the 10 steps
- Do NOT execute permanent delete without a backup
- Do NOT use `Remove-Item` unless every guard has passed
- Do NOT delete PII or secrets without verifying rotation/deletion policy
- Do NOT skip the 60-second delay — it exists for last-minute saves
