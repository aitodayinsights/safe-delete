# Function 10: Recovery & Undo

## Purpose

Provide clear recovery instructions for every delete method. Every delete operation must include a recovery plan before execution.

## Recovery by Delete Method

### Recycle Bin (Default)

**Best case:** File can be restored by the user.

```powershell
# Open Recycle Bin for manual restore
Start-Process shell:RecycleBinFolder

# Programmatic restore (Windows)
$shell = New-Object -ComObject Shell.Application
$rb = $shell.NameSpace(10)  # 10 = Recycle Bin
$items = $rb.Items()
$items | Where-Object { $_.Path -eq $targetPath } | ForEach-Object {
    $rb.InvokeVerb("restore", $_.Path)
}
```

### Backup Restore

```powershell
# From single file backup
Copy-Item -LiteralPath "$env:USERPROFILE\.opencode-trash\2026-05-22_143000-file.tsx" `
          -Destination "./src/components/file.tsx"

# From zip archive
Expand-Archive -LiteralPath "$env:USERPROFILE\.opencode-trash\2026-05-22_143000-backup.zip" `
               -DestinationPath "./" `
               -Force
```

### Git Restore

```powershell
git checkout -- path/to/file              # restore uncommitted
git restore --source=HEAD~1 path/to/file  # restore from previous commit
git checkout <commit-hash> -- path/file   # restore from specific commit
```

### Git Branch Restore (If Deleted)

```powershell
# If branch was deleted with -d (safe delete):
git checkout <commit-hash>
git branch -d branch-name   # already gone
git checkout -b branch-name # recreate from the hash

# If branch was force-deleted (-D) but reflog exists:
git reflog
git checkout -b branch-name HEAD@{n}
```

### Database Transaction Rollback

```sql
-- If transaction is still open:
ROLLBACK;

-- If already committed:
-- Restore from backup table:
INSERT INTO original_table SELECT * FROM backup_table_YYYYMMDD;

-- Restore from CSV:
\COPY original_table FROM 'path\to\backup.csv' CSV HEADER;
```

### Permanent Delete (Hardest Recovery)

⚠ Permanent deletion is designed to be unrecoverable. Recovery options:

```powershell
# 1. Restore from backup (if backup was created — required by protocol)
Expand-Archive -LiteralPath "$env:USERPROFILE\.opencode-trash\perm-2026-05-22_163000-backup.zip" `
               -DestinationPath "./restored/"

# 2. Check if file was in git (even if deleted from disk)
git log --all --full-history -- path/to/file
git checkout <commit-hash> -- path/to/file

# 3. File recovery software (last resort)
# Use Recuva, TestDisk, PhotoRec — no guarantee
# Success depends on disk activity since deletion
```

## Recovery Quick Matrix

| Delete Method | Recoverable? | How | Success Rate |
|---------------|-------------|-----|--------------|
| Recycle Bin | Yes | Open Recycle Bin → Restore | ~100% |
| Backup exists | Yes | Copy from `~/.opencode-trash/` | 100% |
| Git tracked | Yes | `git checkout` or `git restore` | 100% (if committed) |
| Git untracked + no backup | No | File recovery software | Low |
| Database — transaction aborted | Yes | `ROLLBACK` | 100% |
| Database — committed + backup | Yes | Restore from backup table/CSV | 100% |
| Database — committed + no backup | Hard | Point-in-time recovery | Depends on config |
| Permanent + no backup | Very hard | File recovery software | Low–Medium |
| Cloud resource with soft-delete | Yes | AWS/GCP/Azure soft-delete retention | 100% (within window) |
| Cloud resource without soft-delete | Hard | Support ticket + snapshot restore | Depends on provider |

## Best Effort Recovery Checklist

When user asks to undo a delete:

```powershell
1. [ ] Check Recycle Bin
2. [ ] Check ~/.opencode-trash/ for backup
3. [ ] Check git history (git log --full-history)
4. [ ] Check database backup tables
5. [ ] Check cloud provider trash/recycle period
6. [ ] Report what was found and what can be restored
```

## Do Not

- Do NOT promise recovery from permanent delete — it may not be possible
- Do NOT skip creating a recovery plan before every delete
- Do NOT delete backups automatically — keep them until user confirms they're safe to remove
- Do NOT forget about cloud provider retention policies — they may auto-recover
