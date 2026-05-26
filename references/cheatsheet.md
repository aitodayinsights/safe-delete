# Safe Delete — Quick Reference

## Slash Commands

| Command | Effect | Default |
|---------|--------|---------|
| `/safe-delete` | Show current status | — |
| `/safe-delete on` | Full protection (always-bound + watcher offer + triggers) | ✅ Default |
| `/safe-delete off` | Trigger-only mode (no proactive checks) | ❌ |
| `/safe-delete watcher` | Deploy background deletion watcher sub-agent | Off (offered per-task) |
| `/safe-delete status` | Extended status with activity log and stats | — |
| `/safe-delete uninstall` | Self-destruct — remove binding + optionally delete files (triple confirm) | ❌ |

**State persists for session.** Read from config file (AGENTS.md / CLAUDE.md / GEMINI.md) at start.
Set `SAFE_DELETE=off` env var to persist across all sessions.

## Functions Overview

| # | Function | File |
|---|----------|------|
| 00 | Agent behaviour (always-bound, sub-agent watcher) | `../behaviour.md` |
| 01 | Risk scoring (auto 1–10, context-aware modifiers) | `../functions/fn-risk-scoring.md` |
| 01a | CI/CD mode (CI detection, headless auto-defaults) | `../functions/fn-ci-cd.md` |
| 01b | Git-aware protection (tracked/unpushed/dirty/stash) | `../functions/fn-git-aware.md` |
| 01c | Process-aware check (file-in-use detection) | `../functions/fn-process-aware.md` |
| 02 | Delete operations (5 types) | `../functions/fn-delete-methods.md` |
| 03 | Backup & restore (≤100MB auto, >100MB ask) | `../functions/fn-backup.md` |
| 04 | Delete modal (5 options: recycle / backup / permanent / skip / alternative) | `../functions/fn-delete-modal.md` |
| 04a | Language-aware analysis (import graph, auto-update) | `../functions/fn-language-aware.md` |
| 04b | Integrity guard (entry point, only-of-kind, migration chain) | `../functions/fn-integrity-guard.md` |
| 04c | Graphify awareness (dep graph, credit est, install modal) | `../functions/fn-graphify-awareness.md` |
| 04d | Skill integration gate (meta-skill orchestration) | `../functions/fn-skill-integration.md` |
| 04e | Lockfile integrity (manifest + lockfile check) | `../functions/fn-lockfile-integrity.md` |
| 04f | Symlink guard (symlink/hardlink/junction) | `../functions/fn-symlink-guard.md` |
| 04g | Cloud sync guard (OneDrive/Dropbox/iCloud/GDrive) | `../functions/fn-cloud-sync.md` |
| 05 | Permanent delete (guarded) | `../functions/fn-permanent-delete.md` |
| 06 | Audit logging & diary | `../functions/fn-audit.md` |
| 07 | Database safety | `../functions/fn-database.md` |
| 08 | Environment detection | `../functions/fn-environment.md` |
| 09 | Emergency abort | `../functions/fn-emergency.md` |
| 10 | Recovery & undo | `../functions/fn-recovery.md` |
| 11 | Safekeeper (secret layer) | `../functions/fn-safekeeper.md` |
| 12 | Instant mode (`/instant`) | `../functions/fn-instant-mode.md` |

## Always-Bound Rule

**This skill is ALWAYS active.** Before any coding/refactoring/fixing task:
1. Analyze your plan: "Will this require deletion?"
2. If YES → offer sub-agent deletion watcher OR activate manual safe-delete
3. Every delete MUST go through the modal — no exceptions

## Pre-Task Sub-Agent Watcher Offer

```
ASK before complex tasks:
  "This task may involve deleting files. Deploy a background deletion watcher?"
  
  [Yes] → Watcher intercepts all deletes → shows modal automatically
  [No]  → Manual mode: self-monitor + modal before every delete
```

## Delete Modal (5 Options — Always Show)

```
[1] 🗑 Recycle Bin (temp — recoverable)           ← DEFAULT
[2] 💾 Backup then Delete                         ← DEFAULT for risk ≥ 6
[3] ⚡ Permanent Delete (⚠ irreversible)          ← NEVER DEFAULT
[4] ✋ Skip — Don't touch this                   ← Respect user's "no"
[5] 💡 Find Alternative                          ← Suggest rename/archive/deprecate/refactor
```

## Backup Threshold

| File Size | Action |
|-----------|--------|
| **≤ 100 MB** | Auto-backup (no question) |
| **> 100 MB** | Ask user: "Backup first?" |

## Risk Score Quick Calc

```powershell
$score = 1
if ($path -match '\.(sql|db|sqlite)')           { $score += 3 }
if ($path -match '\.(env|key|pem|cert|secret)') { $score += 4 }
if ($path -match '\\production\\|\\prod\\')     { $score += 3 }
$item = Get-Item $path -EA 0
if ($item -and $item.Length -gt 100MB)          { $score += 3 }
elseif ($item -and $item.Length -gt 10MB)       { $score += 2 }
if ($item.PSIsContainer) {
    $newest = Get-ChildItem $path -Recurse -File -EA 0 | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($newest) { $m = $newest.LastWriteTime } else { $m = $item.LastWriteTime }
} else { $m = $item.LastWriteTime }
if ($m -gt (Get-Date).AddHours(-1)) { $score += 3 }
elseif ($m -gt (Get-Date).AddDays(-1)) { $score += 2 }

# Context-aware modifiers (NEW — mandatory for coding tasks)
if ($AgentInitiated)                             { $score += 2 }  # coding side effect
if ($PlanUncertain)                              { $score += 2 }
if ($Migration)                                  { $score += 2 }
if ($RefactorTask)                               { $score += 1 }
if ($UserVerified)                               { $score = [Math]::Max(1, $score - 1) }
if ($BuildArtifact)                              { $score = [Math]::Max(1, $score - 1) }
if ($DryRunConfirmed)                            { $score = [Math]::Max(1, $score - 1) }

# Production guard modifiers (NEW — always check)
# Git-aware (fn-git-aware.md)
if ($hasUnpushed)                                { $score += 3 }
if ($isDirtyWorktree)                            { $score += 1 }
if ($isStaged)                                   { $score += 1 }

# Process-aware (fn-process-aware.md)
if ($isFileInUse)                                { $score += 2 }

# Language-aware (fn-language-aware.md)
if ($importerCount -ge 5)                        { $score += 3 }
elseif ($importerCount -ge 1)                    { $score += 1 }

# Integrity guard (fn-integrity-guard.md)
if ($isEntryPoint)                               { $score += 4 }
if ($isOnlyOfKind)                               { $score += 3 }
if ($isMigrationChain)                           { $score += 4 }
if ($isTestInfrastructure)                       { $score += 2 }

# CI mode (fn-ci-cd.md)
if ($isCIMode -and $score -ge 8)                 { $action = "BLOCK" }  # no modal in CI

# Lockfile integrity (fn-lockfile-integrity.md)
if ($inNodeModules -or $inVendor -or $inPackages) {
    if ($declaredInManifest -and $hasLockfile)   { $score += 3 }
    elseif ($declaredInManifest)                 { $score += 2 }
    if ($workspaceConsumerCount -ge 1)           { $score += 4 }
}

# Symlink guard (fn-symlink-guard.md)
if ($isSymlink -and $targetOutsideProject)       { $score += 5 }
if ($isHardlink -and $linkCount -gt 1)           { $score += 3 }

# Cloud sync guard (fn-cloud-sync.md)
if ($inCloudSync)                                { $score += 3 }
if ($inCloudSync -and $isFileOpen)               { $score += 2 }

# Graphify awareness (fn-graphify-awareness.md)
if ($hasCachedGraph -and $graphDependents -ge 5) { $score += 2 }
elseif ($hasCachedGraph -and $graphDependents -ge 1) { $score += 1 }
if ($graphIsGodNode)                             { $score += 3 }  # top 5% connected

# Skill integration (fn-skill-integration.md)
if ($memoryKitCritical)                          { $score += 1 }  # user-flagged critical

if ($IsDatabase)                                 { $score += 4 }
if ($isBulk -and $count -gt 50)                 { $score += 4 }
elseif ($isBulk -and $count -gt 20)             { $score += 3 }
if ($Path -match '\\Temp\\|\\cache\\')          { $score = [Math]::Max(1, $score - 1) }
[Math]::Min($score, 10)
```

## Delete Commands

### Windows (PowerShell)

```powershell
# File → Recycle Bin (PREFERRED)
Add-Type -AssemblyName Microsoft.VisualBasic
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p, 'OnlyErrorDialogs', 'SendToRecycleBin')

# Directory → Recycle Bin
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($p, 'OnlyErrorDialogs', 'SendToRecycleBin')

# Backup then delete (≤ 100MB auto, > 100MB ask)
if ((Get-Item $p).Length -le 100MB) { $b = Backup($p) }
else { if (Confirm-BackupLargeFile $p) { $b = Backup($p) } }
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p, 'OnlyErrorDialogs', 'SendToRecycleBin')

# Backup zip then delete directory (risk ≥ 6)
$b = Backup-Directory($p); [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($p, 'OnlyErrorDialogs', 'SendToRecycleBin')

# Permanent (triple confirm + written reason + 60s delay)
Remove-Item -LiteralPath $p -Force
```

### macOS / Linux (Bash)

```bash
# File → Recycle Bin (preferred)
# macOS
mv "$path" ~/.local/share/Trash/
# Linux (FreeDesktop)
mv "$path" ~/.local/share/Trash/files/
# Or use trash-cli
trash-put "$path"

# Directory → Recycle Bin
# macOS/Linux
mv "$path" ~/.local/share/Trash/files/
# Or
trash-put "$path"

# Backup then delete (≤ 100MB auto, > 100MB ask)
if [ "$(stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null)" -le 104857600 ]; then
  cp -r "$path" "$backup_dir"
fi
mv "$path" ~/.local/share/Trash/files/

# Backup tar then delete directory (risk ≥ 6)
tar czf "$backup_path.tar.gz" "$path"
mv "$path" ~/.local/share/Trash/files/

# Permanent (triple confirm + written reason + 60s delay)
rm -rf "$path"
```

### Cross-Platform Notes

| OS | Recycle Bin Location | Trash CLI |
|----|---------------------|-----------|
| Windows | `shell:RecycleBinFolder` | Built-in via .NET |
| macOS | `~/.local/share/Trash/` | `brew install trash` |
| Linux (GNOME) | `~/.local/share/Trash/files/` | `trash-cli` |
| Linux (KDE) | `~/.local/share/Trash/` | `trash-cli` |

## Confirmation Levels

| Score | Confirms | Backup | Delay | Modal Required? |
|-------|----------|--------|-------|----------------|
| 1–3 | 1× single modal | Manifest only | 0s | ✅ Always |
| 4–5 | 2× modal + "proceed?" | ≤100MB auto, >100MB ask | 0s | ✅ Always |
| 6–7 | 2× modal + "ABSOLUTELY sure?" + impact | ≤100MB auto zip, >100MB ask | 10s | ✅ Always |
| 8–9 | 3× modal + WCGW + 30s delay + final | ≤100MB auto zip, >100MB ask | 30s | ✅ Always |
| 10 | 3× + written reason + WCGW | ≤100MB auto encrypted, >100MB ask | 60s | ✅ Always |

## Lockfile Integrity Check

```powershell
# npm/pnpm/yarn
if ($path -like "*\node_modules\*") {
    $pkg = ($path -split '\\node_modules\\')[1] -split '\\'[0]
    if (Select-String -Path "package.json" -Pattern "\`"$pkg\`"") { Write-Warning "DECLARED in package.json" }
    if (Test-Path "package-lock.json") { Write-Warning "Lockfile will be stale" }
    Write-Host "Correct action: pnpm remove $pkg / npm uninstall $pkg"
}
```

```bash
# Rust/Cargo
if [ -d "target" ] || [ -d "vendor" ]; then
  grep -q "$CRATE_NAME" Cargo.toml && echo "DECLARED"
  echo "Correct action: cargo remove $CRATE_NAME"
fi
```

## Symlink Quick Check

```powershell
# Windows
$item = Get-Item -LiteralPath $path -Force
if ($item.LinkType -eq "SymbolicLink") { "SYMLINK -> $($item.Target)" }
if ($item.LinkType -eq "Junction")     { "JUNCTION -> $($item.Target)" }
if ($item.LinkType -eq "HardLink")     { "HARDLINK" }
```

```bash
# macOS/Linux
[ -L "$path" ] && echo "SYMLINK -> $(readlink -f "$path")"
[ "$(stat -c%h "$path" 2>/dev/null)" -gt 1 ] && echo "HARDLINK (link count > 1)"
```

## Cloud Sync Detection

```powershell
$env:OneDrive; $env:OneDriveCommercial; $env:DROPBOX
$path -like "$env:OneDrive*" -or $path -like "$env:USERPROFILE\Dropbox*"
```

## CodeFlow (Browser-Based Architecture Map)

Companion tool for visualizing file connections. No CLI — browser-based:

```
# When graphify is not installed + project has a GitHub URL:
#   Suggest: open https://codeflow-five.vercel.app/ → paste repo URL
#
# For local files:
#   Open CodeFlow in browser → click "Open Folder" → select project root
#
# Key features for safe-delete:
#   - Blast radius analysis: pick a file → see what breaks
#   - Dependency graph: interactive architecture visualization
#   - PR Impact Analysis: paste PR URL to see affected files
```

## Graphify Commands

```bash
# Check if installed
graphify --version 2>/dev/null && echo "INSTALLED" || echo "NOT_INSTALLED"

# Check cached graph
test -f graphify-out/graph.json && echo "CACHED" || echo "NOT_CACHED"

# Query deletion impact
graphify query "What depends on $TARGET?" --graph graphify-out/graph.json

# Install (3 methods, auto-detect best)
uv tool install graphifyy          # via uv (fastest)
pipx install graphifyy             # via pipx
pip install graphifyy              # via pip

# Optimal build (no viz, fast mode, cached)
graphify extract . --no-viz --mode fast
```

## Recovery Commands

### Windows (PowerShell)

```powershell
Recycle Bin:     Start-Process shell:RecycleBinFolder
Git restore:     git checkout -- path   or   git restore --source=HEAD~1 path
Backup restore:  Copy-Item $backup $original -Recurse
Safekeeper:      Invoke-RestoreSafekeeper -OriginalPath $path
DB transaction:  ROLLBACK;
DB from backup:  INSERT INTO t SELECT * FROM t_bak;
```

### macOS / Linux (Bash)

```bash
Recycle Bin:     open ~/.local/share/Trash/files/           # macOS
                 ls -la ~/.local/share/Trash/files/          # Linux
Git restore:     git checkout -- path   or   git restore --source=HEAD~1 path
Backup restore:  cp -r "$backup" "$original"
Safekeeper:      ls ~/.local/share/opencode-safekeeper/
DB transaction:  ROLLBACK;
DB from backup:  INSERT INTO t SELECT * FROM t_bak;
```

## Blocked Paths (DO NOT DELETE)

```powershell
# Windows
@('.git\', '.env', 'node_modules\', 'secrets\', 'backup\', '.trash\',
  '.opencode-trash\', 'production\', 'archive\')
```

```bash
# macOS/Linux — same paths, forward slash
patterns=("/.git/" ".env" "node_modules/" ".opencode-trash/" "production/" "archive/")
```

## Semantic Triggers (Quick Check)

| Type | Examples |
|------|---------|
| Direct | `delete`, `remove`, `erase`, `wipe`, `clear`, `destroy`, `purge`, `nuke` |
| Indirect | `get rid of`, `throw away`, `discard`, `uninstall`, `revoke` |
| Concealed | `make space`, `clean up`, `old files`, `junk`, `temp`, `cache`, `spring cleaning` |
| Data-altering | `archive`, `compress`, `reset`, `migrate`, `merge`, `overwrite` |
| **Coding tasks** | `refactor`, `rename`, `replace`, `migrate`, `restructure`, `clean up code`, `remove dead code`, `extract`, `split module` |

## Instant Mode (`/instant`)

```powershell
# Usage: prefix any delete request with /instant
#   "/instant delete dist/"
#   "/instant remove src/old-module"

# What happens:
#   1. Single warning shown (exact box with ╔═╗)
#   2. User types "yes, delete permanently"
#   3. Remove-Item -Force (permanent, no Recycle Bin)
#   4. NO backup, NO safekeeper, NO recovery

# Risk gates:
#   Risk 1-7:   ✅ Pass (single warning)
#   Risk 8-9:   ⚠️ Must type "I UNDERSTAND THE RISK"
#   Risk 10:    🚫 BLOCKED always

# Audit tag: [INSTANT]
```

## Confirmation Levels (Normal vs Instant)

| Score | Normal | `/instant` |
|-------|--------|------------|
| 1–3 | Single modal → Recycle Bin | ✅ warning → "yes, delete permanently" |
| 4–5 | Modal → backup → "proceed?" | ✅ warning → "yes, delete permanently" |
| 6–7 | Modal → backup → "ABSOLUTELY sure?" + 10s | ✅ warning + show risk → "yes" |
| 8–9 | Modal → backup → WCGW → modal → 30s → modal | ⚠️ Must type "I UNDERSTAND THE RISK" |
| 10 | Written reason + 60s | 🚫 **BLOCKED** |

## Safekeeper (Secret Layer)

```powershell
# Enable/Disable (default: enabled)
$env:OPENCODE_SAFEKEEPER = "true"    # enable
$env:OPENCODE_SAFEKEEPER = "false"   # disable

# Hidden backup location:
# %LOCALAPPDATA%\.opencode-safekeeper\

# Automatically called between Step 5 (Backup) and Step 6 (Confirm)
# Call explicitly:
# Invoke-SafekeeperBackup -Path $targetPath -Type "directory"

# Restore from safekeeper:
#   Agent scans manifest.json → finds original path → copies back

# TTL: 24h grace (full recovery) + 24h scheduled (still recoverable) = 48h total
# Status in manifest: active → scheduled → cleaned
```

## Audit Log Location

```
%USERPROFILE%\.opencode-trash\deletion-log.txt
%USERPROFILE%\.opencode-trash\permanent-deletions.log
%LOCALAPPDATA%\.opencode-safekeeper\manifest.json    (safekeeper index, hidden)
%LOCALAPPDATA%\.opencode-safekeeper\cleanup.log      (safekeeper cleanup log)
```

## Quick Decision Flow

```
New task → [CMD] Check safe-delete state
  ├── UNINSTALLED → No protection. Ever. (terminal state — reinstall manually)
  ├── OFF → Skip plan analysis → trigger words only → skip watcher offer
  └── ON  → Plan analysis: deletion needed?
    → No  → Proceed normally
    → Yes → [0a] Git check (tracked/dirty/unpushed/submodule)
          → [0b] Process check (file in use?)
          → [0c] Language check (import graph + importers)
          → [0d] Integrity check (entry point, only-of-kind, migrations)
          → [0e] CI mode check (headless auto-defaults?)
          → [0f] Graphify check (dep graph, credit est, install modal? risk ≥ 4)
          → [0g] Skill integration gate (leverage other installed skills)
          → Offer sub-agent watcher
      → Yes deployed: Watcher intercepts all deletes → shows modal
      → No manual: Self-monitor → modal before every delete
        → User picks option 1-5
          → 1-3: Execute with appropriate guard level
          → 4 (Skip): Stop + find alternative
          → 5 (Alternative): Suggest rename/archive/deprecate
        → Always: Audit log + Verify
```
