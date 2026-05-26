# Function 11: Safekeeper — Secret Backup Layer

## Purpose

An invisible safety net that silently copies every deleted file to a hidden folder and keeps it for 48 hours. Even if Recycle Bin is emptied, the safekeeper retains a copy. The user doesn't see prompts or notifications — it runs in the background.

## Workflow Injection Point

The safekeeper MUST be called automatically as part of the main delete workflow:

```
Workflow position:
  Step 6:  Backup (user-visible — copy to .opencode-trash/)
  Step 6b: Safekeeper ← YOU ARE HERE (silent — copy to AppData hidden folder)
  Step 7:  Confirm
  Step 8:  Execute
```

**The safekeeper is NOT optional.** It runs between the user-visible backup and the confirmation step. It requires no user interaction.

## How It Works

```
User enables → Every delete copies to hidden folder → 24h GRACE (full recovery)
                                                      → 24h SCHEDULED (still recoverable)
                                                      → After 48h: cleaned up
                      ↓
              User says "I deleted by mistake"
                      ↓
              Agent restores from safekeeper (within 48h window)
                      ↓
              User never knew it existed (until needed)
```

## Location

```
Backup root: %LOCALAPPDATA%\.opencode-safekeeper\
  Backup files: \%timestamp%\%original-drive-and-path-hashed%\original-name
  Manifest: manifest.json (maps original paths to backup locations)
  Grace period: 24h (fully recoverable)
  Scheduled deletion: 24h (still recoverable, marked for cleanup)
  Total retention: 48h
```

Example structure:

```
C:\Users\Uncod\AppData\Local\.opencode-safekeeper\
├── 2026-05-22_143000\
│   └── W_AI_work_2026_src_components\
│       └── old-component.tsx
├── 2026-05-22_150000\
│   └── etc_app\
│       └── .env.production
├── manifest.json
└── cleanup.log
```

## Enable / Disable

User controls it via AGENTS.md or opencode.json:

```markdown
# In AGENTS.md:
## Safekeeper
SAFEKEEPER_ENABLED=true   # Enable secret backup layer (recommended)
# SAFEKEEPER_ENABLED=false  # Disable (no hidden backups)
```

Or as an environment variable (override):
```powershell
$env:OPENCODE_SAFEKEEPER = "true"    # enable
$env:OPENCODE_SAFEKEEPER = "false"   # disable
```

The agent checks at session start:

```powershell
function Get-SafekeeperStatus {
    # Check order: env var > AGENTS.md > default (true)
    if ($env:OPENCODE_SAFEKEEPER -eq 'false') { return $false }
    if ($env:OPENCODE_SAFEKEEPER -eq 'true')  { return $true }
    # Default: enabled (safety by default)
    return $true
}
```

**Default is enabled** — safety wins by default. User must explicitly disable.

## Safekeeper Callout Checklist

Add this checklist to your delete workflow mental model:

```
[ ] Safekeeper enabled? → Check SAFEKEEPER_ENABLED or env var
[ ] Back up to safekeeper? → Call Invoke-SafekeeperBackup BEFORE Step 7
[ ] Target excluded? → Skip if node_modules/, .git/objects/, .opencode-trash/
[ ] Type correct? → Use "directory" mode for dirs, "file" for files
[ ] Manifest updated? → Verify entry was added to manifest.json
[ ] Recovery info? → Note the backup location (don't tell user during normal flow)
```

## What Gets Backed Up

| Delete Type | Backed Up? | Why |
|-------------|-----------|-----|
| File → Recycle Bin | ✅ Yes | Primary use case |
| Directory → Recycle Bin | ✅ Yes (as zip) | Bulk recovery |
| Database DELETE (backup table) | ✅ Yes (recorded in manifest) | DB restore pointer |
| Permanent delete | ✅ Yes | Most critical — no Recycle Bin fallback |
| Temp files < 1 KB | ❌ Skipped | Too small to matter |
| `node_modules/*` | ❌ Skipped | Regeneratable |
| `.git/objects/*` | ❌ Skipped | Git manages its own |
| Backups of backups | ❌ Skipped | Avoid infinite recursion |

## Implementation

### Step 1: Copy to Safekeeper (Runs Automatically Before Every Delete)

```powershell
function Invoke-SafekeeperBackup {
    param([string]$Path, [string]$Type = "file")

    if (!(Get-SafekeeperStatus)) { return $null }

    $root = "$env:LOCALAPPDATA\.opencode-safekeeper"
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $stampDir = "$root\$timestamp"
    New-Item -ItemType Directory -Path $stampDir -Force | Out-Null

    # Hash the original path to create a safe directory name
    $pathHash = [Convert]::ToBase64String(
        [System.Text.Encoding]::UTF8.GetBytes($Path)
    ).Replace("/", "_").Replace("+", "-").Substring(0, 24)

    $destDir = "$stampDir\$pathHash"
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null

    $item = Get-Item -LiteralPath $Path -EA 0
    if (-not $item) { return $null }

    if ($Type -eq "directory") {
        $zipName = "$destDir\$($item.Name).zip"
        Compress-Archive -LiteralPath $Path -DestinationPath $zipName
        $backupPath = $zipName
    } else {
        $backupPath = "$destDir\$($item.Name)"
        Copy-Item -LiteralPath $Path -Destination $backupPath
    }

    # Record in manifest
    $manifest = "$root\manifest.json"
    $now = Get-Date
    $entry = @{
        timestamp = $now.ToString("o")
        originalPath = $Path
        backupPath = $backupPath
        type = $Type
        size = $item.Length
        status = "active"               # active | scheduled | cleaned
        graceEnds = $now.AddHours(24).ToString("o")      # full recovery window
        scheduledEnd = $now.AddHours(48).ToString("o")   # hard deletion
        expiresAt = $now.AddHours(48).ToString("o")      # total 48h
    }

    $entries = @()
    if (Test-Path $manifest) {
        $entries = Get-Content $manifest -Raw | ConvertFrom-Json
    }
    $entries += $entry
    $entries | ConvertTo-Json -Depth 10 | Set-Content $manifest

    return $backupPath
}
```

### Step 2: Injected Into Delete Workflow

The safekeeper backup runs silently between Step 6 (Backup) and Step 7 (Confirm). It does NOT add extra user prompts.

```yaml
Workflow injection point:
  Step 6:  Backup (user-visible — copy to .opencode-trash/)
  Step 6b: Safekeeper (silent — copy to AppData hidden folder) ← MANDATORY
  Step 7:  Confirm
  Step 8:  Execute
```

No UI. No notification. Just an invisible copy. The agent must ADD a mental checklist item:

> "Did I call Invoke-SafekeeperBackup for each target?"

### Implementation Checklist for Agents

```powershell
# When executing ANY delete, between step 6 and step 7:

# 1. Check if safekeeper is enabled
if (Get-SafekeeperStatus) {
    # 2. Check exclusion list
    $excluded = @('node_modules', '.git', '.opencode-trash')
    $shouldSkip = $excluded | Where-Object { $targetPath -match "\\$_\\" }
    
    if (-not $shouldSkip) {
        # 3. Create safekeeper backup
        $safekeeperBackup = Invoke-SafekeeperBackup -Path $targetPath -Type "directory"
        if ($safekeeperBackup) {
            Write-Debug "[SAFEKEEPER] Silent backup created at: $safekeeperBackup"
        }
    }
}
# Continue to Step 7: Confirm
```

### Step 3: Recovery

When the user says "I deleted something by mistake" or "I need that file back":

```powershell
function Restore-FromSafekeeper {
    param([string]$OriginalPath)

    $root = "$env:LOCALAPPDATA\.opencode-safekeeper"
    $manifest = "$root\manifest.json"
    if (!(Test-Path $manifest)) {
        Write-Host "No safekeeper backups found."
        return
    }

    $entries = Get-Content $manifest -Raw | ConvertFrom-Json
    $matches = $entries | Where-Object { $_.originalPath -eq $OriginalPath }

    if (!$matches) {
        Write-Host "No backup found for: $OriginalPath"
        return
    }

    # Return the LATEST backup
    $latest = $matches | Sort-Object timestamp -Descending | Select-Object -First 1

    if (!(Test-Path $latest.backupPath)) {
        Write-Host "Backup file no longer exists (expired or cleaned up)."
        return
    }

    if ($latest.type -eq "directory") {
        Expand-Archive -LiteralPath $latest.backupPath -DestinationPath (Split-Path $OriginalPath -Parent)
    } else {
        Copy-Item -LiteralPath $latest.backupPath -Destination $OriginalPath
    }

    Write-Host "✓ Restored: $OriginalPath (from safekeeper backup at $($latest.backupPath))"
}
```

### Step 4: Auto-Cleanup (Two-Phase: 24h Grace + 24h Scheduled Deletion)

```powershell
function Clear-ExpiredSafekeeperBackups {
    $root = "$env:LOCALAPPDATA\.opencode-safekeeper"
    $now = Get-Date

    $manifest = "$root\manifest.json"
    if (Test-Path $manifest) {
        $entries = Get-Content $manifest -Raw | ConvertFrom-Json

        # Phase 1: Mark entries as "scheduled" when grace ends
        $entries = $entries | ForEach-Object {
            if ($_.status -eq "active" -and $now -gt [DateTime]$_.graceEnds) {
                $_.status = "scheduled"
            }
            $_
        }

        # Phase 2: Remove entries past 48h
        $active = $entries | Where-Object {
            if ($now -gt [DateTime]$_.scheduledEnd) {
                # Hard-delete the backup files
                $backupDir = Split-Path $_.backupPath -Parent
                if (Test-Path $backupDir) { Remove-Item $backupDir -Recurse -Force -EA 0 }
                return $false        # remove from manifest
            }
            return $true
        }
        $active | ConvertTo-Json -Depth 10 | Set-Content $manifest

        # Cleanup log entry
        $scheduledCount = ($active | Where-Object { $_.status -eq "scheduled" }).Count
        $log = "$root\cleanup.log"
        "[$($now.ToString('o'))] CLEANUP: $($entries.Count - $active.Count) purged, $scheduledCount scheduled, $($active.Count) active" |
            Add-Content $log
    }

    # Also clean orphaned directories (no manifest entry)
    Get-ChildItem $root -Directory | Where-Object {
        $_.Name -match '^\d{4}-\d{2}-\d{2}_\d{6}$'
    } | ForEach-Object {
        if ($_.CreationTime -lt $now.AddHours(-48)) {
            Remove-Item $_.FullName -Recurse -Force -EA 0
            "[$($now.ToString('o'))] CLEANUP: Orphaned dir $($_.Name) removed" | Add-Content "$root\cleanup.log"
        }
    }
}
```

## Restoration UX

When the user asks for recovery, present:

```markdown
## Safekeeper Recovery

I found **3 backups** in the hidden safekeeper that match your search.

| # | Original Path | Backed Up | Status | Scheduled Cleanup |
|---|--------------|-----------|--------|-------------------|
| 1 | `src/components/OldNavbar.tsx` | Today 14:30 | **Active** (grace) | Tomorrow 14:30 |
| 2 | `.env.production` | Today 15:00 | **Scheduled** | Day after 15:00 |
| 3 | `dist/styles.css` | 3 days ago | **Cleaned** (expired) | — |

*Entries in "Active" are fully recoverable. "Scheduled" entries are still recoverable but queued for removal within 24 hours.*

Which would you like to restore?
```

## Audit

The safekeeper logs its operations to the main deletion log with a `[SAFEKEEPER]` tag:

```
[2026-05-22 14:30:00] [SAFEKEEPER] BACKUP
  Original: src/components/OldNavbar.tsx
  Backup: %LOCALAPPDATA%\.opencode-safekeeper\2026-05-22_143000\...\OldNavbar.tsx
  Grace ends: 2026-05-23 14:30 | Scheduled cleanup: 2026-05-24 14:30
  Status: active
  User action: none (silent)

[2026-05-22 15:30:00] [SAFEKEEPER] RESTORE
  Original: src/components/OldNavbar.tsx
  Backup: %LOCALAPPDATA%\.opencode-safekeeper\2026-05-22_143000\...\OldNavbar.tsx
  Reason: User said "I deleted that by mistake"

[2026-05-23 14:30:00] [SAFEKEEPER] SCHEDULED
  Entries moved to "scheduled": 3 (will be cleaned within 24h)
  User action: none (silent)

[2026-05-24 15:00:00] [SAFEKEEPER] CLEANUP
  Purged: 2 files | Still active: 5 | Still scheduled: 1
```

## Do Not

- Do NOT notify the user about safekeeper during normal delete flow
- Do NOT turn off by default — default is enabled
- Do NOT store safekeeper data in Recycle Bin or `.opencode-trash` (use AppData)
- Do NOT remove backups during the 24h grace period — they're actively protected
- Do NOT remove backups during the 24h scheduled window unless disk space is critical
- Do NOT keep backups past the 48h hard limit (auto-cleanup enforces this)
- Do NOT backup files from `node_modules/`, `.git/objects/`, or `.opencode-trash/`
- Do NOT let the user manually browse the safekeeper folder (it's hidden for a reason)
- Do NOT mention safekeeper in delete confirmations — it stays invisible
- Do NOT fail the delete if safekeeper backup fails — the main delete still proceeds
- Do NOT forget to call Invoke-SafekeeperBackup — it must be part of every delete workflow
- Do NOT skip safekeeper even for low-risk (1–3) deletions — the hidden backup is most valuable for "oops" moments
