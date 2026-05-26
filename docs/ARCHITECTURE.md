# Architecture

## Overview

Safe-Delete is a layered safety system that sits between an AI coding agent and the filesystem. It intercepts deletion operations, scores risk, analyzes impact, presents options, and ensures recoverability.

```
┌──────────────────────────────────────────────────────┐
│                   TRIGGER LAYER                       │
│  Always-Bound  │  Slash Commands  │  Semantic Trigger │
│  Plan Analysis │  /safe-delete    │  Trigger Words    │
│  Sub-Agent     │  on/off/watcher  │  Intent Detection │
└────────────────────────┬─────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────┐
│                  ANALYSIS LAYER                       │
│  Risk Scoring    │  Impact Analysis   │  Git Check    │
│  fn-risk-scoring │  Process Check     │  fn-git-aware │
│  Language Check  │  Integrity Check   │  fn-language  │
│  fn-process-aware│  fn-integrity-guard│  fn-ci-cd     │
└────────────────────────┬─────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────┐
│                  DECISION LAYER                       │
│  Delete Modal with 5 Options                          │
│  [1] Recycle Bin  [2] Backup+Delete                   │
│  [3] Permanent    [4] Skip    [5] Alternative         │
└────────────────────────┬─────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────┐
│               EXECUTION LAYER                         │
│  Backup (fn-backup) → Safekeeper (fn-safekeeper)     │
│  → Either: Recycle Bin OR Permanent Delete           │
│  → Verify → Audit Log (fn-audit)                     │
└──────────────────────────────────────────────────────┘
```

---

## Data Flow

```
User: "refactor auth.js into smaller modules"
        │
        ▼
[1] SKILL.md activates (always-bound)
        │
        ▼
[2] behaviour.md checks safe-delete state
    ├── ON (default): proceed to plan analysis
    └── OFF: skip to trigger detection
        │
        ▼
[3] Plan analysis detects deletion needed
        │
        ▼
[4] Offer sub-agent watcher to user
    ├── Yes: watcher intercepts all file removals
    └── No: manual monitoring
        │
        ▼
[5] When deletion is about to happen:
    ├── fn-risk-scoring.md → score 1-10
    ├── fn-git-aware.md → check git status
    ├── fn-process-aware.md → check running processes
    ├── fn-language-aware.md → check import graph
    ├── fn-integrity-guard.md → check project structure
    └── fn-ci-cd.md → check CI mode (if applicable)
        │
        ▼
[6] fn-delete-modal.md → present 5-option modal
        │
        ├── [1] Recycle Bin → fn-delete-methods.md
        ├── [2] Backup+Delete → fn-backup.md → fn-delete-methods.md
        ├── [3] Permanent → fn-permanent-delete.md
        ├── [4] Skip → log + stop
        └── [5] Alternative → suggest rename/archive/refactor
        │
        ▼
[7] fn-safekeeper.md → invisible backup (always)
        │
        ▼
[8] fn-audit.md → log to deletion-log.txt
        │
        ▼
[9] fn-recovery.md → generate recovery instructions
```

---

## File Relationships

```
SKILL.md ───────────────────────────────────────────────────┐
  ├── commands.md  (slash commands, state machine)          │
  ├── behaviour.md (triggers, cognitive checks, flow)       │
  └── functions/                                            │
      ├── fn-delete-methods.md  ─── required by ── SKILL.md │
      ├── fn-risk-scoring.md    ─── used by ── modal, flow  │
      ├── fn-delete-modal.md    ─── used by ── all deletes  │
      ├── fn-backup.md          ─── called by ── modal [2]  │
      ├── fn-audit.md           ─── called by ── every step │
      ├── fn-database.md        ─── DB-specific              │
      ├── fn-permanent-delete.md ─── guarded delete          │
      ├── fn-environment.md     ─── dev/prod detection       │
      ├── fn-emergency.md       ─── halt on "stop"          │
      ├── fn-recovery.md        ─── undo everything          │
      ├── fn-safekeeper.md      ─── secret backup layer      │
      ├── fn-instant-mode.md    ─── fast delete bypass       │
      ├── fn-ci-cd.md           ─── NEW: CI/CD safety        │
      ├── fn-git-aware.md       ─── NEW: git protection      │
      ├── fn-process-aware.md   ─── NEW: process check       │
      ├── fn-language-aware.md  ─── NEW: import graph check  │
      └── fn-integrity-guard.md ─── NEW: project structure   │
```

---

## State Machine

```
                    ┌─────────────┐
                    │  SESSION     │
                    │  START       │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │ READ CONFIG  │
                    │ AGENTS.md    │
                    │ env vars     │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │   ON     │ │   OFF    │ │ WATCHER  │
        └────┬─────┘ └────┬─────┘ └────┬─────┘
             │            │            │
      ┌──────┴──────┐  ┌──┴───┐  ┌────┴──────┐
      │ Plan check  │  │Trig. │  │ Watcher   │
      │ Watcher off.│  │words │  │ auto-depl.│
      │ Full flow   │  │only  │  │ Full flow │
      └──────┬──────┘  └──┬───┘  └────┬──────┘
             │            │            │
             ▼            ▼            ▼
      ┌─────────────────────────────────────┐
      │         STATE TRANSITIONS            │
      │  /safe-delete on/off/watcher/status  │
      │  Persists for session length          │
      │  Re-reads config on session start     │
      └─────────────────────────────────────┘
```

---

## Storage Architecture

```
Filesystem
├── ~/.opencode-trash/
│   ├── deletion-log.txt          # Permanent audit trail
│   ├── permanent-deletions.log   # Guarded permanent log
│   └── backups/                  # User-visible backups
│       └── {timestamp}_{path_hash}/
│           ├── manifest.json
│           └── data/
│
└── ~/.local/share/opencode-safekeeper/   # (Unix) or
    %LOCALAPPDATA%\.opencode-safekeeper\  # (Windows)
        ├── manifest.json           # Secret index
        ├── cleanup.log             # Auto-cleanup log
        └── {uuid}/
            ├── files/
            └── meta.json           # Original paths, TTL
```

---

## Key Design Principles

1. **Defense in depth** — Multiple layers (analysis → decision → execution → persistence) ensure no single bypass is catastrophic
2. **Always recoverable** — Every delete has an undo path (Recycle Bin, backup, safekeeper, git)
3. **Context-aware** — Risk scoring adapts to file type, size, age, git status, running processes, and import relationships
4. **User in control** — The 5-option modal gives users full agency, including the option to refuse entirely
5. **Platform-agnostic** — Works across Windows/macOS/Linux and all major AI coding agents
6. **Invisible by default** — The safekeeper layer works silently without user friction
7. **Audit-first** — Every operation is logged permanently for accountability
