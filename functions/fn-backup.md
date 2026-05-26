# Function 03: Backup & Restore

## Purpose

Before any delete (risk ≥ 4), automatically create a recoverable backup. The backup system stores copies in `%USERPROFILE%\.opencode-trash\` with timestamps.

## Backup Threshold Rule (100 MB)

| File Size | Action |
|-----------|--------|
| **≤ 100 MB** | Auto-backup — no question needed |
| **> 100 MB** | Ask user: "This file/folder is X MB. Do you want me to back it up first?" |

### Rationale:
- Small files (< 100 MB) are fast to backup — just do it silently
- Large files (> 100 MB) may take significant time/disk space — user should decide
- The modal (option 2) already signals the user wants backup; this is a courtesy confirmation for large files
- If user declines backup for > 100 MB, log the decision and proceed with delete

## Backup Methods

### 01 — Single File Backup

```powershell
function Backup-File {
    param([string]$Path)
    $backupDir = "$env:USERPROFILE\.opencode-trash"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $ts = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $name = Split-Path $Path -Leaf
    $dest = "$backupDir\$ts-$name"
    Copy-Item -LiteralPath $Path -Destination $dest
    return $dest
}
```

### 02 — Directory Backup (Zip Archive) — MANDATORY for Risk ≥ 6

```powershell
function Backup-Directory {
    param([string]$Path)
    $backupDir = "$env:USERPROFILE\.opencode-trash"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $ts = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $name = Split-Path $Path -Leaf
    $dest = "$backupDir\$ts-$name.zip"
    Compress-Archive -LiteralPath $Path -DestinationPath $dest
    return $dest
}
```

**⚠ Risk ≥ 6 requires zip archive.** Single-file copy is not sufficient for directories at High risk and above.

### 03 — Manifest Generation (Minimum for Risk 1–3)

Even for low-risk deletions, generate a manifest listing what was deleted:

```powershell
function New-DeleteManifest {
    param([string[]]$Paths, [string]$Reason)
    $backupDir = "$env:USERPROFILE\.opencode-trash"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $ts = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $manifest = "$backupDir\$ts-manifest.txt"
    
    @"
Delete Manifest
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
User: $env:USERNAME
Reason: $Reason

Targets:
"@ | Out-File -FilePath $manifest -Encoding UTF8

    foreach ($p in $Paths) {
        $item = Get-Item -LiteralPath $p -EA 0
        if ($item) {
            "$($item.FullName) | $([math]::Round($item.Length/1MB, 1)) MB | $($item.LastWriteTime)" |
                Out-File -FilePath $manifest -Append -Encoding UTF8
        }
    }
    return $manifest
}
```

### 04 — Database Table Backup (SQL Dump)

```sql
-- PostgreSQL:
CREATE TABLE table_name_bak_YYYYMMDD AS TABLE table_name;
\COPY table_name TO 'backupDir/table_name_bak_YYYYMMDD.csv' CSV HEADER;

-- MySQL:
CREATE TABLE table_name_bak_YYYYMMDD AS SELECT * FROM table_name;
SELECT * INTO OUTFILE 'backupDir/table_name.csv' FROM table_name;

-- SQLite:
CREATE TABLE table_name_bak_YYYYMMDD AS SELECT * FROM table_name;
.output backupDir/table_name.sql
.dump table_name
```

### 05 — Database Row Backup (Before DELETE)

```sql
BEGIN;
-- Backup rows before deleting
CREATE TABLE rows_bak_YYYYMMDD AS SELECT * FROM target_table WHERE condition;
-- Verify count
SELECT COUNT(*) FROM rows_bak_YYYYMMDD;
-- Then proceed with DELETE if user confirms
-- ROLLBACK; or COMMIT;
```

### 06 — Environment File Backup

```powershell
# .env files are not git-tracked — backup is critical
$backup = Backup-File ".env.production"
Write-Host "⚠ .env backed up to: $backup"
Write-Host "⚠ Restore with: Copy-Item '$backup' '.env.production'"
```

## When to Auto-Backup

| Condition | Backup Type | Always or Optional? |
|-----------|-------------|---------------------|
| Risk < 4 | Manifest only | Minimum |
| Risk ≥ 4, file ≤ 100 MB | Single file copy | Auto — no question |
| Risk ≥ 4, file > 100 MB | Single file copy | Ask user first |
| Risk ≥ 6, file ≤ 100 MB | Zip archive | Auto — no question (replaces single copy) |
| Risk ≥ 6, file > 100 MB | Zip archive | Ask user first¹ |
| Risk ≥ 8 | Zip + SQL dump | Always (even if > 100 MB) |
| `.env` files | Single file copy | Always |
| Database operation | SQL dump or backup table | Always |
| Config files | Single file copy | Always |
| User requests backup | Whatever they specify | Always |

¹ For risk ≥ 6 and > 100 MB: ask "This file is X MB. Do you want me to back it up first?" If user declines, log the decision and proceed without backup.

## Restore Functions

### From Backup File

```powershell
# Single file
Copy-Item -LiteralPath "$env:USERPROFILE\.opencode-trash\2026-05-22_143000-config.js" `
          -Destination "./config.js"

# From zip archive
Expand-Archive -LiteralPath "$env:USERPROFILE\.opencode-trash\2026-05-22_143000-backup.zip" `
               -DestinationPath "./restored/"
```

### From Database Backup

```sql
-- From backup table:
INSERT INTO original_table SELECT * FROM backup_table_YYYYMMDD;

-- From CSV:
\COPY original_table FROM 'backupDir/file.csv' CSV HEADER;
```

## Large File Backup Confirmation

For files > 100 MB where backup is optional:

```powershell
function Confirm-BackupLargeFile {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -EA 0
    if (-not $item) { return $true }  # item doesn't exist, skip

    $sizeMB = [math]::Round($item.Length / 1MB, 1)
    if ($item.PSIsContainer) {
        $total = (Get-ChildItem -Path $Path -Recurse -File -EA 0 | Measure-Object Length -Sum).Sum
        $sizeMB = [math]::Round($total / 1MB, 1)
    }

    if ($sizeMB -le 100) { return $true }  # ≤ 100 MB, auto-backup

    # > 100 MB — ask user
    # Use question tool where available
    Write-Host "⚠ This file/folder is ${sizeMB}MB (> 100 MB)."
    $response = Read-Host "Do you want me to back it up first? (Y/N)"
    return ($response -eq 'Y' -or $response -eq 'y')
}
```

## Backup Verification

After creating any backup, verify it:

```powershell
function Test-BackupIntegrity {
    param([string]$BackupPath)
    if (-not (Test-Path $BackupPath)) {
        Write-Error "Backup file missing: $BackupPath"
        return $false
    }
    $item = Get-Item $BackupPath
    if ($item.Length -eq 0) {
        Write-Error "Backup is empty: $BackupPath"
        return $false
    }
    return $true
}
```

## Do Not

- Do NOT skip backup when risk ≥ 4
- Do NOT skip zip archive when risk ≥ 6 — a manifest is NOT sufficient for High risk
- Do NOT store backups in the same directory as the target (use `~/.opencode-trash/`)
- Do NOT overwrite existing backups — always timestamp
- Do NOT delete backups automatically — keep until user confirms they don't need them
- Do NOT skip backup verification — confirm the backup is valid before deleting
- Do NOT skip manifest generation even for risk 1 — always leave a record
- Do NOT auto-backup files > 100 MB without asking the user first
- Do NOT assume user wants backup just because it's risk ≥ 6 — large files need explicit consent
- Do NOT skip logging when user declines backup — record the decision in the audit log
