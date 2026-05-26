# Function 01: Delete Operations

## 5 Delete Types Available

| Type | Code | Risk Range | Default |
|------|------|------------|---------|
| File (single) | `DELETE_FILE` | 1–10 | Recycle Bin |
| Directory | `DELETE_DIR` | 1–10 | Recycle Bin |
| Batch / Bulk | `DELETE_BULK` | 3–10 | Summary → Each → Recycle Bin |
| Database | `DELETE_DB` | 6–10 | Backup → Transaction → Rollback/Commit |
| Permanent | `DELETE_PERM` | 8–10 | Triple confirm → Written reason → 60s delay |

---

## 01 — DELETE_FILE: Single File

**Default method for all file deletions.**

```powershell
# ALWAYS use Recycle Bin
Add-Type -AssemblyName Microsoft.VisualBasic
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
  $targetPath,
  'OnlyErrorDialogs',
  'SendToRecycleBin'
)
```

**Before executing, the agent MUST:**

1. Inspect the file
   - For text files: read first 10 lines
   - For binary files (see exception below): show file type, size, last modified, origin
2. Check git status (tracked? modified? history?)
3. Check if any file imports or references it
4. Calculate risk score via `fn-risk-scoring.md`
5. Present structured question to user

**Binary file content preview exception:**

For binary files (`.gguf`, `.dll`, `.exe`, `.so`, `.dylib`, `.bin`, `.dat`, `.zip`, `.tar`, `.gz`, `.7z`, `.rar`, `.iso`, `.img`, `.pdf`, `.png`, `.jpg`, `.mp3`, `.mp4`, `.avi`, `.mov`, `.o`, `.a`, `.lib`):

- SKIP the "read first 10 lines" requirement
- Instead show: `{filename} | {size} | {last modified} | {type}`
- For archives: show file count inside
- For partial downloads (`.part`): note it's incomplete

**User presentation template:**

```markdown
### DELETE: {path}
**Risk:** {score}/10 ({label})
**Size:** {size} | **Modified:** {date}
**Git:** {status} ({n} commits)

**Contents preview (first 10 lines or file metadata):**
```
{lines or type/size/origin}
```

**Why delete?** {reason}
**What breaks?** {imports, services, dependencies affected}
**Recovery:** {Recycle Bin/git/backup}

[ ] Proceed — Recycle Bin
[ ] Backup first
[ ] Cancel
```

---

## 02 — DELETE_DIR: Directory (Recursive)

```powershell
Add-Type -AssemblyName Microsoft.VisualBasic
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
  $dirPath,
  'OnlyErrorDialogs',
  'SendToRecycleBin'
)
```

**Extra requirements:**
- Show file count + total size inside the directory
- List subdirectory structure (top 2 levels)
- Show the 5 largest files inside
- Note if any files inside are git-tracked
- Check if directory contains config, env, or DB files (risk bump)
- Check if directory contains partial downloads (`.part`, `.crdownload`)

---

## 03 — DELETE_BULK: Batch / Bulk Delete

Used when deleting 2+ files or when using glob patterns.

```powershell
$files = Get-ChildItem -Path $path -Filter $pattern -Recurse -File
$total = $files.Count
$totalSize = ($files | Measure-Object Length -Sum).Sum

# Show summary table
$files | Group-Object Extension | Select-Object Name, Count,
    @{N='Size';E={[math]::Round(($_.Group | Measure-Object Length -Sum).Sum/1KB, 1)}}

# If > 20 files, show only top 10 + note "and N more"
$display = $files | Select-Object -First 10 FullName, Length, LastWriteTime
Write-Host "Showing 10 of $total files..."

# After user confirmation:
$files | ForEach-Object {
    Add-Type -AssemblyName Microsoft.VisualBasic
    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
        $_.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin'
    )
}
```

**Rules:**
- If > 5 files: show grouped summary by extension, not individual listing
- If > 20 files: risk bump to +3
- If > 50 files: risk bump to +4, show sample of 10 only
- If any tracked file in batch: warn user individually
- Never batch-delete into `.git/`, `node_modules/`, `.env` — require per-file review

---

## 04 — Multi-Target Grouped Operations

When deleting multiple independent targets (e.g., clearing caches AND deleting models):

```markdown
### Grouped Delete Plan
| # | Target | Size | Risk | What Breaks |
|---|--------|------|------|-------------|
| 1 | npm cache (`C:\Users\...\npm-cache`) | 2.11 GB | 2/10 | Auto-rebuilds |
| 2 | LM Studio models (`...\.lmstudio\models`) | 7.36 GB | 6/10 | Re-download needed |
| 3 | AnythingLLM storage | 6.08 GB | 6/10 | Re-download needed |

**Overall risk level: 6 (High)** — using highest individual risk
```

**Rules for grouped operations:**
1. Score each target individually
2. Use the **highest** score for the confirmation level
3. Backup each target separately before any deletion
4. Present as a single curated list with checkboxes
5. Execute sequentially (one at a time)
6. Verify each after execution
7. Audit as a grouped entry

---

## 05 — Second Confirmation Template (Risk ≥ 6)

After backup is complete and user has given first confirmation, present the second confirmation:

```markdown
### SECOND CONFIRMATION REQUIRED

**Are you ABSOLUTELY sure you want to delete these files?**

| Target | Size | Backup Location |
|--------|------|-----------------|
| {path} | {size} | `{backup path}` |

**What breaks if I delete this:**
- {dependency 1}
- {dependency 2}

**Recovery options:**
- Recycle Bin: Open and restore
- Backup: Copy from `{backup path}`
- Re-download: {source URL if applicable}

**Alternatives:**
- [ ] Archive instead of delete
- [ ] Rename to .bak instead
- [ ] Move to external drive
- [ ] Proceed with delete → Recycle Bin
- [ ] Cancel
```

For risk 8+: present a third confirmation:

```markdown
### THIRD CONFIRMATION — FINAL

You have confirmed twice already. This is your last chance to cancel.

**What could go wrong:**
| Scenario | Impact |
|----------|--------|
| Immediate failure | {what breaks right now} |
| Silent corruption | {what breaks later} |
| Data loss | {what cannot be recovered} |
| Regret | {you realize you need it later} |

Type "I confirm" to proceed, or anything else to cancel.
```

---

## 06 — Question Tool Integration

When the platform provides a structured question tool:

| Confirmation # | Risk 1–3 | Risk 4–5 | Risk 6–7 | Risk 8–9 | Risk 10 |
|---------------|----------|----------|----------|----------|---------|
| 1st | Single question with Proceed/Cancel | Question with Proceed/Backup first/Cancel | Question with Proceed/Backup first/Cancel | Question with Proceed/Backup first/Cancel | Question with Proceed/Backup first/Cancel |
| 2nd | — | "Backup done. Proceed?" | "Backup done. Are you ABSOLUTELY sure?" | Full WCGW analysis + question | Full WCGW + question |
| 3rd | — | — | — | "Final confirm — 30s remaining?" | Written reason prompt |
| Delay | 0s | 0s | 10s pause | 30s pause | 60s pause |

Map options as follows:

```powershell
# Risk 1-3: Single question
$question = @{
    header = "Confirm delete"
    question = "Delete {path} ({size})? It will go to Recycle Bin."
    options = @(
        @{label="Proceed"; description="Send to Recycle Bin"},
        @{label="Cancel"; description="No changes"}
    )
}

# Risk 6-7: Second confirm after backup
$question = @{
    header = "⚠️ ABSOLUTELY SURE?"
    question = "Backup done at {path}. Are you sure you want to delete {size} of files?"
    options = @(
        @{label="Yes, proceed"; description="Send to Recycle Bin"},
        @{label="Show me what breaks first"; description="Detailed impact analysis"},
        @{label="Cancel"; description="No changes"}
    )
}
```

---

## 07 — "What Could Go Wrong" Analysis (Risk ≥ 6)

Generate this table and show the user before final confirmation:

| Scenario | Impact |
|----------|--------|
| **Immediate failure** | {what breaks right now} |
| **Silent corruption** | {what breaks later, silently} |
| **Data loss** | {what data is permanently gone} |
| **Security incident** | {if cert/key/secret — outage or breach} |
| **Regret** | {user realizes they need it after it's gone} |

---

## Confirmation Matrix

| Risk | Normal Mode | `/instant` Override |
|------|-------------|---------------------|
| 1–3 | **Single confirm**: Present once, user approves or cancels | ✅ Single warning → "yes, delete permanently" |
| 4–5 | **Confirm + backup**: Present, backup, then confirm again | ✅ Single warning → "yes, delete permanently" |
| 6–7 | **Double confirm**: Present → backup → "Are you ABSOLUTELY sure?" + impact report + 10s delay | ✅ Single warning + show risk score → "yes, delete permanently" |
| 8–9 | **Triple confirm**: Present → backup → "WCGW" → second question → 30s delay → third question | ⚠️ Must type "I UNDERSTAND THE RISK" |
| 10 | **Written reason**: Present → backup → impact → "What could go wrong" → "Write your reason" → 60s delay | 🚫 **BLOCKED** — use normal protocol |

---

## Do Not

- Do NOT skip the contents preview — read before deleting (for binary: show metadata)
- Do NOT use permanent delete unless all guards pass
- Do NOT batch-delete tracked files without individual warning
- Do NOT delete files you haven't checked for references/imports
- Do NOT accept vague reasons — push for specifics
- Do NOT skip the second confirmation for risk ≥ 6
- Do NOT skip the "What could go wrong" analysis for risk ≥ 6
- Do NOT skip the delay for risk ≥ 6 (10s), ≥ 8 (30s), or 10 (60s)
- Do NOT treat binary files as text — use metadata instead of "first 10 lines"
- Do NOT mix targets with different risk levels without using the highest level
- Do NOT skip backup for any target in a grouped operation — backup each one
