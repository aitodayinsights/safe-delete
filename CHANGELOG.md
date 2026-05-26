# Changelog

All notable changes to safe-delete are documented here.

## [2.1.0] — 2026-05-26 — Sentinel

### Added
- **Graphify awareness** (`fn-graphify-awareness.md`) — dependency graph integration with credit estimation, install suggestion modal (3 options), and structure cache
- **Skill integration gate** (`fn-skill-integration.md`) — meta-orchestration that detects and leverages graphify, claude-memory-kit, CodeFlow, and sibling fn-* skills for enriched delete context
- **Lockfile integrity guard** (`fn-lockfile-integrity.md`) — package manager manifest + lockfile detection with workspace consumer analysis, suggests correct `uninstall/remove` tool
- **Symlink guard** (`fn-symlink-guard.md`) — symlink/hardlink/junction detection with recursive resolution, +5 risk for outside-project targets
- **Cloud sync guard** (`fn-cloud-sync.md`) — OneDrive/Dropbox/iCloud/Google Drive detection via env vars and KnownFolderId, +3 risk modifier
- **CodeFlow companion** — browser-based architecture map suggestion when GitHub URL exists and graphify isn't available
- **`/safe-delete uninstall` command** — triple-confirm self-destruct with written reason, option binding-only vs full uninstall, terminal UNINSTALLED state
- **Production guard count: 18** (up from 15)

### Changed
- SKILL.md — expanded workflow with steps 0h–0j (lockfile, symlink, cloud-sync), updated functions table (entries 06e–06g)
- INDEX.md — entries 15e–15g + companion tools table
- behaviour.md — decision flow extended with steps 3h–3j
- cheatsheet.md — added risk-scoring modifiers, quick-check commands for all 3 new guards
- README.md — version badge 2.1.0, expanded features table, updated architecture diagram and project structure

## [2.0.0] — 2026-05-26 — Production Shield

### Added
- **CI/CD pipeline safety** (`fn-ci-cd.md`) — headless mode, CI detection, rollback PR hooks
- **Git-aware protection** (`fn-git-aware.md`) — unpushed commit guard, dirty worktree check, stash suggestion
- **Process-aware deletion** (`fn-process-aware.md`) — running process check, file handle detection
- **Language-aware import guard** (`fn-language-aware.md`) — import graph analysis for Python, JS/TS, Rust, Go, Java
- **Project integrity guard** (`fn-integrity-guard.md`) — entry point protection, migration history guard, config file safety
- **Repo-level documentation** — README.md, CONTRIBUTING.md, CHANGELOG.md, LICENSE (MIT)
- **Build system** — Makefile, version.json, install.sh, validate.sh, test-prereqs.sh
- **CI** — GitHub Actions workflow with structure validation, markdown linting, and test execution
- **GitHub templates** — bug report, feature request, PR template
- **Test suite** — test-skill-structure.sh, test-risk-scoring.ps1, test-risk-scoring.sh, test-scenarios.md
- **Architecture docs** — ARCHITECTURE.md, DESIGN-DECISIONS.md, PLATFORMS.md, USAGE.md
- **Real-world examples** — coding-refactor.md, deployment-cleanup.md, database-migration.md
- **Bash equivalents** for all PowerShell delete commands (cross-platform support)

### Changed
- SKILL.md updated with 5 new production feature sections
- Functions table in SKILL.md updated (now 19 functions including 5 new)
- INDEX.md updated with new function references
- `fn-delete-modal.md` — now checks CI mode and auto-defaults in headless environments
- `fn-backup.md` — added cross-session backup index and integrity verification
- `fn-recovery.md` — added undo-by-task, backup listing by date
- `behaviour.md` — added CI/headless flow, git-aware check step, process check step
- `commands.md` — improved cross-platform mapping

### Fixed
- All function headers match SKILL.md numbering
- Path references consistent across all files

## [1.0.0] — 2026-05-25 — Foundation

### Added
- Always-Bound Rule — safe-delete activates during ALL agent tasks
- Proactive Deletion Watcher Sub-Agent — background monitoring during complex tasks
- 5-Option Delete Modal — Recycle Bin, Backup+Delete, Permanent, Skip, Find Alternative
- 100MB auto-backup threshold (≤100MB auto, >100MB ask)
- Context-Aware Risk Modifiers — AgentInitiated (+2), Migration (+2), RefactorTask (+1), etc.
- Slash Commands — `/safe-delete on/off/watcher/status`
- Secret Safekeeper — invisible 48h backup in AppData
- Audit logging with deletion diary
- Cross-platform tool mapping (OpenCode, Claude Code, Cursor, Codex, Copilot, Gemini)
- Configuration persistence (AGENTS.md, CLAUDE.md, GEMINI.md, .cursorrules, env vars)

### Core Functions
- fn-delete-methods.md — 5 delete operation types
- fn-risk-scoring.md — Auto risk scoring with context-aware modifiers
- fn-delete-modal.md — Interactive 5-option modal
- fn-backup.md — Backup & restore
- fn-audit.md — Audit logging
- fn-database.md — Database safety
- fn-permanent-delete.md — Guarded permanent deletion
- fn-environment.md — Dev/staging/prod detection
- fn-emergency.md — Emergency abort
- fn-recovery.md — Recovery
- fn-safekeeper.md — Secret backup layer
- fn-instant-mode.md — Conscious fast delete
