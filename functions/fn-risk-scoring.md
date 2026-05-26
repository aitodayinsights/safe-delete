# Function 02: Risk Scoring

## Purpose

Auto-calculate a risk score (1–10) for any delete target so the agent applies the correct level of protection.

## Context-Aware Modifiers

The risk score is adjusted based on the **context** of the deletion, not just the target itself:

| Context | Modifier | Why |
|---------|----------|-----|
| **User explicitly requested deletion** | Base score | User knows what they want |
| **Agent-initiated deletion** (coding task side effect) | **+2** | User may not expect files to be removed as a side effect of refactoring |
| **Sub-agent watcher deployed** | **+0** | Watcher provides proactive oversight — no extra penalty |
| **Coding task — plan analysis uncertain** | **+2** | Agent isn't sure if deletion is needed — be extra careful |
| **Migration/upgrade task** | **+2** | Old files from migrations are often still needed (rollback) |
| **Refactor/extract task** | **+1** | Extracted code may still have references |
| **Cleanup after verification** (user confirmed it's safe) | **-1** | User has already verified the cleanup is safe |
| **Build artifact / generated file** | **-1** | Can be regenerated — lower risk |
| **Dry-run confirmed** | **-1** | User saw the simulation and approved |

## How It Works

```
Start with score = 1
For each matching factor below, add points
Cap at 10 (Catastrophic)
```

## Scoring Factors

| Factor | Points | Condition |
|--------|--------|-----------|
| **Base** | 1 | Always |
| File is SQL/DB | +3 | `.sql`, `.db`, `.sqlite`, `.mdb`, `.accdb` |
| Database operation | +4 | DROP, TRUNCATE, DELETE (SQL command) |
| Env/secret/key | +4 | `.env`, `.env.*`, `credentials`, `secret`, `key`, `pem`, `cert`, `p12` |
| Production path | +3 | `production`, `prod\`, `live\`, `staging\`, `master\`, `main\` in path |
| Production connection | +3 | Connection string points to production DB |
| File > 10 MB but ≤ 100 MB | +2 | Moderate-size file |
| File > 100 MB | +3 | Large file (cumulative, replaces +2 for >10MB) |
| Modified < 1 hour | +3 | Recently changed — probably still in use |
| Modified < 24 hours | +2 | Today's work |
| Modified < 7 days | +1 | Recent work |
| Git tracked with changes | +1 | Has uncommitted modifications |
| Bulk > 20 files | +3 | Large batch |
| Bulk > 50 files | +4 | Very large batch (cumulative, replaces +3 for >20) |
| User said "everything"/"all" (vague) | +5 | Vague instruction — dangerous |
| User said "everything" from curated options | +2 | Less dangerous — user chose from structured list |
| User seems frustrated | +3 | User rushing — pauses forced |
| File open in editor/process | +3 | File is locked/in use |
| Only copy (no backup) | +3 | No backup exists for this data |
| Config file | +3 | `package.json`, `tsconfig.json`, `*.config.*`, `Dockerfile`, etc. |
| Partial download file | -1 | `.part`, `.crdownload`, `.downloading` — safe to remove if download cancelled |
| Cache/temp directory | -1 | Known safe-to-clear directories (`Temp`, `cache`, `logs`, `Recycle Bin`) |
| **Agent-initiated deletion** (coding side effect) | +2 | User didn't explicitly ask to delete — deletion is a side effect of refactoring/migration |
| **Coding task — plan analysis uncertain** | +2 | Agent isn't sure if deletion will be needed — be extra careful |
| **Migration/upgrade task** | +2 | Old files from migrations are often still needed for rollback |
| **Refactor/extract task** | +1 | Extracted code may still have hidden references |
| **Cleanup after user verification** | -1 | User confirmed cleanup is safe (e.g., "yes, I checked, delete the old one") |
| **Build artifact / generated file** | -1 | Can be regenerated from source (e.g., `dist/`, `build/`, `.next/`) |
| **Dry-run confirmed** | -1 | User saw the simulation output and approved |
| Database — DDL (DROP/ALTER/TRUNCATE) | +5 | Schema-level changes more dangerous than data changes |
| Database — rows > 1,000 | +2 | Mass delete |
| Database — rows > 10,000 | +3 | Force batch mode |
| Database — rows > 100,000 | +4 | Force production approval gate |
| Database — no WHERE clause | +5 | Unqualified DELETE/UPDATE = full table mutation |
| Database — no index on WHERE column | +3 | Seq scan = table lock + slow execution |
| Database — active queries on same table | +3 | Risk of lock contention |
| Database — outside business hours | +2 | Fewer people available to fix issues |
| Database — production + risk >= 8 | +2 | Enables approval gate + 5min cooldown |
| Database — no transaction support | +4 | SQLite auto-commit, no ROLLBACK possible |
| Database — replication lag detected | +2 | DELETE may cascade to replicas with delay |

## Score → Action Mapping

| Score | Label | Confirms | Backup | Impact Report | Delay | Execution | DB Extra |
|-------|-------|----------|--------|---------------|-------|-----------|----------|
| 1–3 | **Low** | 1 (single question) | Manifest only | No | 0s | Recycle Bin | — |
| 4–5 | **Medium** | 2 (question + "proceed?") | Yes — file copy | Summary | 0s | Recycle Bin | EXPLAIN ANALYZE |
| 6–7 | **High** | 2 (question + backup + "ABSOLUTELY sure?") | Yes — zip archive | Full "What breaks?" | 10s | Recycle Bin | Dry-run + EXPLAIN |
| 8–9 | **Critical** | 3 (question + backup + "WCGW" + question + delay + question) | Yes — zip + SQL dump | Full + "What could go wrong" | 30s | Recycle Bin only | Approval gate + batch mode + rollback script + 5min cooldown |
| 10 | **Catastrophic** | 3 + written reason | Yes — encrypted | Full + "What could go wrong" + peer review | 60s | BLOCKED unless human verifies | DBA review required |

## PowerShell Implementation

```powershell
function Get-RiskScore {
    param(
        $Path, $IsGitTracked, $IsDatabase, $FileCount, $IsProduction, $UserUrgency,
        $DbRowCount, $DbIsDDL, $DbNoWhere, $DbNoIndex, $DbActiveQueries,
        $DbOutsideHours, $DbNoTransaction, $DbReplicationLag,
        # Context-aware parameters (new)
        [switch]$AgentInitiated,    # deletion is side effect of coding/refactoring
        [switch]$PlanUncertain,     # agent isn't sure if deletion is needed
        [switch]$Migration,         # migration/upgrade task
        [switch]$RefactorTask,      # refactor/extract task
        [switch]$UserVerified,      # user confirmed cleanup is safe
        [switch]$BuildArtifact,     # generated/build file
        [switch]$DryRunConfirmed    # user saw dry-run and approved
    )
    $score = 1

    # File type factors
    if ($Path -match '\.(sql|db|sqlite|mdb|accdb)$')        { $score += 3 }
    if ($Path -match '\.(env|\.env\.|credentials|secret|key|pem|cert|p12)$') { $score += 4 }

    # Path/environment factors
    if ($Path -match '\\production\\|\\prod\\|\\live\\|\\staging\\')         { $score += 3 }

    # Size factors (>10MB = +2, >100MB = +3 cumulative, not additive)
    $item = Get-Item $Path -EA 0
    if ($item -and $item.Length -gt 100MB)  { $score += 3 }
    elseif ($item -and $item.Length -gt 10MB) { $score += 2 }

    # Time factors (check most recently modified file in directory)
    if ($item) {
        $m = $item.LastWriteTime
        if ($item.PSIsContainer) {
            $newest = Get-ChildItem -Path $Path -Recurse -File -EA 0 |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($newest) { $m = $newest.LastWriteTime }
        }
        if ($m -gt (Get-Date).AddHours(-1)) { $score += 3 }
        elseif ($m -gt (Get-Date).AddDays(-1)) { $score += 2 }
        elseif ($m -gt (Get-Date).AddDays(-7)) { $score += 1 }
    }

    # Git tracking
    if ($IsGitTracked)       { $score += 1 }

    # Database operation
    if ($IsDatabase)         { $score += 4 }

    # Bulk file count
    if ($FileCount -gt 50)   { $score += 4 }
    elseif ($FileCount -gt 20) { $score += 3 }

    # Production environment
    if ($IsProduction)       { $score += 3 }

    # User urgency/frustration
    if ($UserUrgency)        { $score += 3 }

    # Database-specific factors
    if ($DbRowCount -gt 100000) { $score += 4 }
    elseif ($DbRowCount -gt 10000) { $score += 3 }
    elseif ($DbRowCount -gt 1000) { $score += 2 }
    if ($DbIsDDL)             { $score += 5 }
    if ($DbNoWhere)           { $score += 5 }
    if ($DbNoIndex)           { $score += 3 }
    if ($DbActiveQueries)     { $score += 3 }
    if ($DbOutsideHours)      { $score += 2 }
    if ($DbNoTransaction)     { $score += 4 }
    if ($DbReplicationLag)    { $score += 2 }
    if ($IsDatabase -and $score -ge 8) { $score += 2 }

    # Context-aware modifiers (NEW)
    if ($AgentInitiated)      { $score += 2 }  # user didn't explicitly ask to delete
    if ($PlanUncertain)       { $score += 2 }  # plan analysis uncertain
    if ($Migration)           { $score += 2 }  # old files needed for rollback
    if ($RefactorTask)        { $score += 1 }  # hidden references may exist
    if ($UserVerified)        { $score = [Math]::Max(1, $score - 1) }  # user confirmed safe
    if ($BuildArtifact)       { $score = [Math]::Max(1, $score - 1) }  # regenerable
    if ($DryRunConfirmed)     { $score = [Math]::Max(1, $score - 1) }  # simulation approved

    # Safe-to-clear modifiers (subtractive)
    if ($Path -match '\\Temp\\|\\cache\\|\\logs\\') { $score = [Math]::Max(1, $score - 1) }
    if ($Path -match '\.(part|crdownload|downloading)$') { $score = [Math]::Max(1, $score - 1) }

    return [Math]::Min($score, 10)
}
```

## Do Not

- Do NOT override the score — it must be auto-calculated, not guessed
- Do NOT skip factors — apply ALL matching factors to get accurate score
- Do NOT round down — a score of 6.9 is still 7 (High), not 6
- Do NOT assume all cache files are safe — still check size and age
- Do NOT add +5 for "delete everything" when the user chose from curated options — use +2 instead
- Do NOT forget to apply context-aware modifiers — they're mandatory for coding/refactoring tasks
- Do NOT skip the `$AgentInitiated` flag when deletion is a side effect of a coding task — this is the most important new modifier
- Do NOT apply both `$AgentInitiated` AND `$BuildArtifact` if it's a build artifact during a coding task — apply both (they may cancel out)
- Do NOT assume build artifacts are always safe — large build directories still need backup considerations
