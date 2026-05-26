# Test Scenarios

This document defines acceptance test scenarios for safe-delete. Each scenario tests a specific behavior.

---

## Basic Operation

| # | Scenario | Steps | Expected | Risk |
|---|----------|-------|----------|------|
| 1 | Normal file delete | User asks agent to delete a small text file | Modal appears with 5 options, file goes to Recycle Bin | 1 |
| 2 | Bulk delete (3 files) | User asks agent to delete multiple small files | Modal appears for each or grouped by option | 2 |
| 3 | Large file >100MB | User asks agent to delete a 200MB file | Auto-backup skipped, user asked first, then Recycle Bin | 3 |
| 4 | Directory delete | User asks agent to delete a directory | Modal appears, directory goes to Recycle Bin | 3 |

---

## Risk Scoring

| # | Scenario | Expected Score | Notes |
|---|----------|---------------|-------|
| 5 | Delete a 5KB log file | 1-2 | Temp file, small |
| 6 | Delete a 50KB config file | 4-5 | Config file, prod path |
| 7 | Delete a 2GB video file | 5-6 | Large, but not critical |
| 8 | Delete a SQLite database | 8-10 | +4 DB file |
| 9 | Delete a secret/key file | 6-7 | +4 env/key file |
| 10 | Delete modified git-tracked file | 5-6 | +1 tracked, + within 24h |
| 11 | Agent-initated bulk delete | +3 to all | +2 agent-initiated, +3 bulk |
| 12 | CI pipeline delete | Auto-default, no modal | Risk-based, CI format output |

---

## Always-Bound

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 13 | Refactor (no mention of delete) | User says "refactor auth module" | Always-bound catches implicit deletion |
| 14 | Clean cache (no mention of delete) | User says "speed up the build" | Always-bound catches cache cleanup |
| 15 | Replace file | User says "replace config.js with new one" | Always-bound catches overwrite |
| 16 | Rename file | User says "rename utils.js to helpers.js" | Always-bound catches rename (delete original) |

---

## Git-Aware

| # | Scenario | Steps | Expected | Risk + |
|---|----------|-------|----------|--------|
| 17 | Delete untracked file | File not in git | Normal flow, no extra | 0 |
| 18 | Delete tracked file with unpushed commits | File has unpushed changes | Warning + st ash suggestion | +3 |
| 19 | Delete staged file | File is staged for commit | Stash/commit suggestion | +1 |
| 20 | Delete modified tracked file | File has local changes | Stash/commit/revert suggestions | +1 |
| 21 | Delete file in submodule | File is part of a submodule | Warning + submodule-specific | +2 |

---

## Process-Aware

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 22 | Delete file open in editor | File is open in VS Code | Warning: in use by VS Code, options |
| 23 | Delete config file used by running service | Config is loaded by a running Docker container | Warning: in use by Docker, suggest stop first |
| 24 | Delete file not in use | No process has the file open | Normal flow, no warning |
| 25 | Delete file with wait + retry | File temporarily locked (e.g., build in progress) | Wait, retry, then proceed or skip |

---

## Language-Aware

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 26 | Delete Python file with imports | helpers.py is imported by 5 modules | Warning: 5 files import this, show importers list |
| 27 | Delete TypeScript file with re-exports | types/index.ts re-exports from types/user.ts | Warning: import chain, suggest updating barrel file |
| 28 | Delete Rust module | utils/mod.rs is declared in lib.rs | Warning: module declaration, suggest removing mod |
| 29 | Delete isolated file | No imports reference this file | Normal flow, no extra warnings |
| 30 | Delete config file with dependency | package.json depends on tsconfig.json existence | Warning: config dependency chain |

---

## Integrity Guard

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 31 | Delete entry point | Agent tries to delete src/main.py | Blocked: entry point, suggest alternative |
| 32 | Delete only-of-its-kind | Agent tries to delete the only Dockerfile | Warning: only Dockerfile, 3 files reference it |
| 33 | Delete migration in chain | Agent tries to delete an intermediate migration | Blocked: migration chain, suggest reversal |
| 34 | Delete test infrastructure | Agent tries to delete conftest.py or test runner config | Warning: test infrastructure, 10+ tests depend |
| 35 | Delete only stylesheet component | Agent tries to delete the only CSS file for a component | Warning: only stylesheet, suggest renaming instead |

---

## CI/CD Mode

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 36 | CI pipeline, low risk | CI env detected, delete a temp file | Auto: backup, no modal |
| 37 | CI pipeline, high risk | CI env detected, delete a config file | Auto: block, no modal |
| 38 | CI pipeline, SAFE_DELETE_CI=true | Env var set, delete high-risk file | Allow: user has explicitly opted in |
| 39 | CI pipeline, HEADLESS=true | Headless env detected (no terminal) | Same as CI: risk-based auto defaults |

---

## Slash Commands

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 40 | /safe-delete status | User checks status | Shows ON/OFF/WATCHER, config, recent activity |
| 41 | /safe-delete off | User turns off proactive monitoring | No always-bound check, trigger words still work |
| 42 | /safe-delete on | User turns protection back on | Full protection restored |
| 43 | /safe-delete watcher | User deploys watcher | Background watcher deployed for session |
| 44 | /safe-delete while a file is open | User tries to delete while OFF | If file is open, still warned (process-aware) |

---

## Recovery

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 45 | Restore from Recycle Bin | File was deleted via Recycle Bin | Restored from `shell:RecycleBinFolder` |
| 46 | Restore from backup | File was deleted via Back up+Delete | Restored from `~/.opencode-trash/backups/` |
| 47 | Restore from git | File was tracked + deleted | `git restore --source=HEAD~1 path` |
| 48 | Restore from safekeeper | File was permanently deleted | Last resort restore from safekeeper |
| 49 | Purge old backups | Run cleanup on backups older than 48h | Old backups removed, recent kept |

---

## Edge Cases

| # | Scenario | Steps | Expected |
|---|----------|-------|----------|
| 50 | Delete symlink | Agent tries to delete symlink | Symlink deleted, target file preserved |
| 51 | Delete read-only file | Agent tries to delete readonly file | Warning: readonly, suggest unlock first |
| 52 | Delete with special chars | File name has spaces, parens, unicode | Proper quoting, no errors |
| 53 | Delete hidden file | Agent tries to delete .env.local | Warning: hidden + env file |
| 54 | Empty directory delete | Agent tries to delete empty dir | Normal flow, lower risk |
| 55 | Permission denied | Agent has no delete permission | Error: permission denied, suggest alternative |
| 56 | Very long path | Path >260 chars | UNC path handling (Windows) |
| 57 | Network drive file | File is on network share | Warning: network drive, may be slow |
