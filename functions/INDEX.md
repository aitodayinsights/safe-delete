# Safe Delete — Functions Catalog

## Commands & Behaviour

| # | Function | File | Purpose |
|---|----------|------|---------|
| CMD | **Slash commands** | `../commands.md` | `/safe-delete on/off/watcher/status/uninstall` — runtime control + self-destruct, state machine, persistent config |
| 00 | **Agent behaviour** | `../behaviour.md` | Semantic triggers, cognitive checks, agent stance, decision flow, sub-agent watcher, always-bound rule |

## Core Delete Operations (5 types)

| # | Function | File | Risk Range | Default Action |
|---|----------|------|------------|----------------|
| 01 | **File delete** (single) | `fn-delete-methods.md` | 1–10 | Modal → Recycle Bin |
| 02 | **Directory delete** | `fn-delete-methods.md` | 1–10 | Modal → Recycle Bin |
| 03 | **Batch/bulk delete** | `fn-delete-methods.md` | 3–10 | Modal → Summary → Recycle Bin |
| 04 | **Database delete** (rows, tables) | `fn-database.md` | 6–10 | Modal → Backup → Transaction → Rollback/Commit |
| 05 | **Permanent delete** | `fn-permanent-delete.md` | 8–10 | Modal → Triple confirm → Written reason → 60s delay |

## Support Functions

| # | Function | File | Purpose |
|---|----------|------|---------|
| 06 | **Risk scoring** | `fn-risk-scoring.md` | Auto-calculate risk score (1–10) from ALL factors including context-aware modifiers for coding tasks |
| 06a | **CI/CD mode** | `fn-ci-cd.md` | CI environment detection (8+ signals), headless mode, risk-based auto-defaults, rollback PR automation |
| 06b | **Git-aware protection** | `fn-git-aware.md` | 5 git checks (tracked/unpushed/dirty/staged/submodule), +3 risk for unpushed, stash flow, branch protection |
| 06c | **Process-aware check** | `fn-process-aware.md` | File-in-use detection (PowerShell/Bash/lsof/fuser), locking process ID, wait-retry, graceful shutdown |
| 07 | **Backup & restore** | `fn-backup.md` | Auto-backup before delete; ≤100MB auto, >100MB ask; restore on demand |
| 08 | **Audit logging** | `fn-audit.md` | Permanent 15+ field log of every delete attempt, plus session diary |
| 09 | **Environment detection** | `fn-environment.md` | Detect dev/staging/production from 8+ signals |
| 10 | **Dependency analysis** | `fn-delete-methods.md` | Check import graph, FK relationships, running processes |
| 11 | **"What could go wrong"** | `fn-delete-methods.md` | Generate failure scenario analysis table for risk ≥ 6 |
| 12 | **Emergency abort** | `fn-emergency.md` | Halt in-progress delete, issue ROLLBACK, provide recovery |
| 13 | **Recovery & undo** | `fn-recovery.md` | Restore from Recycle Bin, git, backup, safekeeper, or DB |
| 14 | **Confirmation matrix** | `fn-delete-methods.md` | 1–3 confirmations + question tool integration based on risk |
| 15 | **Delete modal** | `fn-delete-modal.md` | Interactive modal with 5 options — temp, backup, permanent, skip, alternative. Includes multi-target and large-file handling. |
| 15a | **Language-aware analysis** | `fn-language-aware.md` | Import graph analysis for Python/JS/TS/Rust/Go/Java, auto-update imports on rename |
| 15b | **Integrity guard** | `fn-integrity-guard.md` | Entry point protection, only-of-kind detection, migration chain blocking, config dependency mapping |
| 15c | **Graphify awareness** | `fn-graphify-awareness.md` | Dependency graph detection, credit estimation (file-count heuristic), install suggestion modal with 3 options, structure cache reuse |
| 15d | **Skill integration gate** | `fn-skill-integration.md` | Meta-skill orchestration — detect & leverage other skills (graphify, claude-memory-kit, fn-language-aware) for enriched delete context |
| 15e | **Lockfile integrity** | `fn-lockfile-integrity.md` | Package manager manifest + lockfile check for node_modules/vendor/packages/target |
| 15f | **Symlink guard** | `fn-symlink-guard.md` | Symlink/hardlink/junction detection, target vs link distinction |
| 15g | **Cloud sync guard** | `fn-cloud-sync.md` | OneDrive/Dropbox/iCloud/Google Drive detection, multi-device sync warning |
| 16 | **Deletion diary** | `fn-audit.md` | Session-level running log of all operations |
| 17 | **Safekeeper** (secret layer) | `fn-safekeeper.md` | Invisible 48h backup in AppData, survives Recycle Bin empty |
| 18 | **Instant mode** (`/instant`) | `fn-instant-mode.md` | Conscious fast delete — bypasses all safety, no backup, no recovery |
| 19 | **Multi-target grouped** | `fn-delete-methods.md` | Orchestrate multiple independent delete targets with unified risk and confirm |
| 20 | **Binary file exception** | `fn-delete-methods.md` | Skip "first 10 lines" for binary files; show metadata instead |
| 21 | **Question tool integration** | `fn-delete-methods.md` | Map confirmation levels to platform question tool |

## Companion Tools

These external tools are referenced by safe-delete but live outside the skill:

| Tool | Purpose | How to Access |
|------|---------|---------------|
| **Graphify** | Full dependency graph CLI | `pipx install graphifyy` or `uv tool install graphifyy` |
| **CodeFlow** | Browser-based architecture map | [codeflow-five.vercel.app](https://codeflow-five.vercel.app/) — paste any GitHub URL |
| **Claude Memory Kit** | Cross-session persistent memory | `pip install claude-memory-kit` or clone from GitHub |
