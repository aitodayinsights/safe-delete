# Function 14: Git-Aware Protection

## Purpose

Prevent agents from deleting files that have unpushed commits, dirty worktrees, or are tracked in a way that would lose work. Integrates with git to check file status before any delete operation.

---

## Detection Checks

Before any delete, run these git checks in order:

### Check 1: Is this a git repository?

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

```powershell
git rev-parse --is-inside-work-tree 2>$null
```

If not a git repo → skip all git checks.

### Check 2: Is the file tracked?

```bash
git ls-files --error-unmatch "$path" >/dev/null 2>&1
```

If NOT tracked (new/untracked file) → low concern. Log as "untracked".

### Check 3: Does the file have unpushed commits?

```bash
# Check if the file has changes that exist in commits not yet pushed
git log --oneline -- "$path" 2>/dev/null | head -5
git log --oneline --branches --not --remotes -- "$path" 2>/dev/null
```

If unpushed commits modify this file → **block** with warning.

### Check 4: Is the working tree dirty for this file?

```bash
# Check for uncommitted changes
git diff --name-only -- "$path" 2>/dev/null | grep -q .
# Check for staged changes
git diff --cached --name-only -- "$path" 2>/dev/null | grep -q .
```

If dirty → **elevate risk** + suggest stash first.

### Check 5: Does this file exist in an active branch?

```bash
# Check which branches contain this file
git branch --contains HEAD -- "$path" 2>/dev/null
```

If this is the only branch containing this file → **critical** flag.

---

## Risk Modifiers

| Condition | Risk Adjustment |
|-----------|----------------|
| File has unpushed commits | +3 (minimum risk 7) |
| File has uncommitted changes | +2 |
| File is staged (git add) | +1 |
| File exists on only one branch | +2 |
| File is untracked (new) | 0 (normal scoring applies) |
| File is gitignored | -1 (likely build artifact) |
| Directory is a git submodule | +3 |
| File is in `.git/` | +4 (BLOCKED) |

```powershell
function Get-GitRiskModifier {
    param([string]$Path)

    $modifier = 0
    $isTracked = git ls-files --error-unmatch $Path 2>$null
    if (-not $isTracked) { return 0 }  # untracked

    # Check unpushed commits
    $unpushed = git log --oneline --branches --not --remotes -- $Path 2>$null
    if ($unpushed) { $modifier += 3 }

    # Check dirty worktree
    $dirty = git diff --name-only -- $Path 2>$null
    if ($dirty) { $modifier += 2 }

    # Check staged changes
    $staged = git diff --cached --name-only -- $Path 2>$null
    if ($staged) { $modifier += 1 }

    # Check submodule
    $submodule = git submodule status -- $Path 2>$null
    if ($submodule) { $modifier += 3 }

    return $modifier
}
```

---

## Git-Aware Modal Message

When git issues detected, the modal shows:

```
┌─────────────────────────────────────────────────────────────┐
│ ⚠ GIT-AWARE: Unpushed Changes Detected                      │
│                                                              │
│ Target: src/config.ts                                        │
│                                                              │
│ ⚠ This file has unpushed commits (3 commits behind origin)   │
│ ⚠ This file has uncommitted changes                          │
│                                                              │
│ Would you like to:                                            │
│                                                              │
│ [1] Stash changes, then Recycle Bin   (safe)                  │
│ [2] Commit + Push first, then delete  (safe)                  │
│ [3] Backup then Recycle Bin           (caution — loses git)  │
│ [4] Skip — keep the file              (default)               │
│ [5] Find Alternative                                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Stash-Before-Delete Workflow

If user agrees to stash:

```bash
git stash push -m "safe-delete: auto-stash before deleting $path"
# Then delete
```

Or commit-before-delete:

```bash
git add "$path"
git commit -m "safe-delete: final state of $path before removal"
git push
# Then delete
```

---

## Branch Protection Rules

Safe-Delete respects git branch protection:

| Branch Pattern | Protection |
|----------------|-----------|
| `main`, `master` | Extra confirmation required |
| `production` | BLOCKED unless explicit override |
| `release/*` | Backup required before any delete |
| `gh-pages` | Backup + confirm |
| Any protected (git hooks) | Respect hook output |

---

## Git Hooks Integration

Safe-Delete can install a pre-delete hook that runs git checks automatically:

```bash
# .git/hooks/pre-safe-delete (generated)
#!/bin/bash
# This hook runs before safe-delete proceeds
# Exit 0 = allow, Exit 1 = block

path="$1"
if git log --oneline --branches --not --remotes -- "$path" 2>/dev/null | grep -q .; then
    echo "BLOCKED: $path has unpushed commits"
    exit 1
fi
exit 0
```

---

## Do Not

- Do NOT delete files with unpushed commits without warning and offering stash first
- Do NOT delete `.git/` files — always blocked
- Do NOT skip git check for tracked files — always check
- Do NOT assume `git stash` will work — check for merge conflicts first
- Do NOT delete dirty worktree files without offering stash/commit alternatives
- Do NOT ignore git submodule status — submodules have their own git history
