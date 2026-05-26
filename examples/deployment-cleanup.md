# Example: Deployment Cleanup Walkthrough

## Scenario

A developer asks an agent to clean up old build artifacts and deployment scripts after a migration from Jenkins to GitHub Actions.

**Goal:** Remove outdated CI/CD scripts, old deployment configs, and stale build output

**Risk:** An old `deploy-to-prod.sh` is deleted alongside `jenkins-pipeline.groovy` — both have historical value

---

## Step 1: Agent Scans the Project

```
User: "Our CI uses GitHub Actions now. Let's clean up the old Jenkins stuff."

Agent: Scanning for Jenkins-related files...

  Found 14 files:
  ├── jenkins/Jenkinsfile             ← pipeline definition
  ├── jenkins/scripts/*.groovy         ← 4 shared lib files
  ├── jenkins/config.groovy           ← config
  ├── deploy/deploy-to-prod.sh        ← USED? Check...
  ├── deploy/deploy-to-staging.sh     ← USED? Check...
  ├── deploy/rollback.sh              ← USED? Check...
  ├── deploy/ansible/                 ← 4 inventory files
  └── deploy/docker-compose.old.yml   ← old compose file

  [safe-delete] Process-aware check:
  ⚠ deploy-to-prod.sh is referenced by running docker service
  ⚠ (docker-compose.yml line 12: command: ./deploy-to-prod.sh)

  ⚠ Process-aware check:
  ⚠ deploy-to-prod.sh is currently in use by Docker
  ⚠ PID 4823 (docker-compose)
```

---

## Step 2: Integrity Guard Analysis

```
[Integrity guard activated]
[Checking project structure — entry points, critical paths]

  ⚠ Entry Point Check:
  ✓ src/main.py — not affected
  ✓ tsconfig.json — not affected
  ✓ Dockerfile — references deploy-to-staging.sh
  ✓ Makefile — has deploy targets

  ⚠ Only-of-its-Kind Check:
  ✓ deploy-to-prod.sh — only script that handles prod deploy
  ⚠ Can't simply delete — need to verify replacement works

  ⚠ Dependency Analysis:
  deploy-to-prod.sh referenced by:
    - docker-compose.yml:12
    - Makefile:44 (deploy target)
    - README.md: "run deploy-to-prod.sh to deploy"
```

---

## Step 3: Bulk Deletion Initiated

```
[Agent tries to delete 14 Jenkins/deploy files]

[safe-delete] ⚠ Bulk operation: 14 targets

┌──────────────────────────────────────────────────┐
│ ⚠ BULK DELETE: 14 files                          │
│                                                   │
│ [1] Recycle Bin All         [2] Backup + Delete   │
│ [3] Review Each             [4] Skip All          │
│ [5] Find Alternative                              │
└──────────────────────────────────────────────────┘

User selects: [3] Review Each
```

---

## Step 4: File-by-File Review

```
File 1/14: jenkins/Jenkinsfile
  Size: 8 KB | Modified: 3 months ago
  [1] Bin  [2] B+Del  [3] Perm  [4] Skip  [5] Alt

  User: "1"
  ✓ Jenkinsfile → Recycle Bin

File 2/14: jenkins/scripts/pipeline-lib.groovy
  [1] Bin  [2] B+Del  [3] Perm  [4] Skip  [5] Alt

  User: "4"  (skip — might reference in future)
  ⏭ Skipped

...

File 8/14: deploy/deploy-to-prod.sh
  ⚠ PROCESS-AWARE: In use by Docker (PID 4823)
  ⚠ INTEGRITY GUARD: Only script deploying to production
  [1] Bin  [2] B+Del  [3] Perm  [4] Skip  [5] Alt

  User: "5" (Find Alternative)

  Agent suggests:
    a) Keep + ignore (leave for now)
    b) Rename to deploy-to-prod.legacy.sh
    c) Stop Docker service, then delete

  User: "b"
  ✓ deploy-to-prod.sh → deploy-to-prod.legacy.sh
  ✓ Docker still references it (update docker-compose next)
  ✓ Documented in migration notes
```

---

## Step 5: Process-Aware Escape

```
File 11/14: deploy/ansible/inventory-prod.ini
  ⚠ PROCESS-AWARE: Open in VS Code
  [1] Bin  [2] B+Del  [3] Perm  [4] Skip  [5] Alt

  User: "4" (Skip)
  ⏭ inventory-prod.ini not deleted (still open in VS Code)
```

---

## Summary

```
Cleanup Result:
  ✅ 10 files → Recycle Bin
  ⏭  2 files → Skipped (keep for now)
  🔄  1 file  → Renamed (deploy-to-prod.sh → .legacy.sh)
  🔄  1 file  → Alternative (mig rate to GH Actions)

  Disk freed: 3.2 MB
  Storage used by backups: 2.1 MB
  Audit log: ~/.opencode-trash/deletion-log.txt

  Recovery available via:
  - Recycle Bin: 10 files
  - Safekeeper: all 14 backed up
  - Nothing was permanently deleted
```

---

## Key Observations

1. **Process-aware check caught a live Docker reference** — prevented a production crash
2. **Integrity guard flagged the only production deploy script** — prevented a dangerous gap
3. **File-by-file review let the user make informed choices** — bulk "yes" would have been dangerous
4. **Alternatives gave a middle path** — rename instead of delete kept the file intact
