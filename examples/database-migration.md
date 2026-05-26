# Example: Database Migration Walkthrough

## Scenario

A developer asks an agent to "fix the broken migration" in a Django project.

**Goal:** Roll back or remove a corrupted migration that's blocking new migrations

**Risk:** Deleting a migration file breaks the migration chain and corrupts the database state

---

## Step 1: Agent Diagnoses the Problem

```
User: "Migration 003_add_tags is broken. Can you fix it?"

Agent: Checking migration status...

  Migration chain:
  ├── 001_initial.sql          ✓ applied
  ├── 002_add_users.sql        ✓ applied
  ├── 003_add_tags.sql         ✗ BROKEN (applied, but contains error)
  └── 004_add_indexes.sql      BLOCKED (depends on 003)

  [safe-delete] Database mode activated
  ⚠ This is a database migration — special handling required
```

---

## Step 2: Integrity Guard Blocks Delete

```
Agent: "I'll delete 003_add_tags.sql and recreate it."

[safe-delete] ⚠ INTEGRITY GUARD: Migration Chain Protection

┌──────────────────────────────────────────────────┐
│ ⚠ BLOCKED: Migration File Deletion               │
│                                                   │
│ 003_add_tags.sql cannot be safely deleted         │
│                                                   │
│ The migration chain will break:                   │
│   001 → 002 → 003 → [004 blocked]                 │
│                                                   │
│ Deleting 003 while it's applied will:             │
│   • Leave the database in an inconsistent state    │
│   • Break the migration dependency chain           │
│   • Prevent new migrations from running            │
│                                                   │
│ [1] Create reversal migration  (✓ safest)        │
│ [2] Skip — keep the broken file                   │
│ [3] Force delete (⚠ breaks chain entirely)       │
└──────────────────────────────────────────────────┘
```

---

## Step 3: User Chooses Safest Option

```
User selects: [1] Create reversal migration

Agent: Creating reversal migration...

  Created: db/migrations/005_reverse_003.sql
  Contents:
    ALTER TABLE posts DROP COLUMN tags;
    -- Reverses the broken 003_add_tags

  Migration chain:
    001 → 002 → 003 (broken) → 004 [blocked]
    → [RUN 005_reverse_003] → 004 [unblocked]

  ✓ Reversal migration created
  ✓ Original 003_add_tags.sql preserved (for reference)
  ✓ 004_add_indexes.sql now unblocked
  ✓ Chain is valid
```

---

## Step 4: Alternative Scenario — Fresh Project with No Data

```
User: "Actually, this is a dev database with no data. Just nuke it."

[safe-delete]
  Risk Score: 8 (HIGH — database operation)
  │ +4 database file
  │ +2 modified within 24h
  │ +1 git tracked
  │ +1 multiple migrations depend on it

┌──────────────────────────────────────────────────┐
│ ⚠ Risk Score: 8 — Database Migration Delete      │
│                                                   │
│ File: db/migrations/003_add_tags.sql              │
│ Type: SQL Migration                               │
│ Applied: Yes (currently in database state)        │
│                                                   │
│ [1] Create reversal migration  (✓ safest)        │
│ [2] Backup + delete (backup + recreate from zero) │
│ [3] Force delete          ⚠ will break DB state   │
│ [4] Skip                                          │
│ [5] Full reset (all migrations from scratch)      │
└──────────────────────────────────────────────────┘

User selects: [3]

⚠ Risk 8 — Requires 2 confirmations:
  "Database operation. Are you sure? [y/N]"
  You: "y"
  "This will leave the database in an inconsistent state. Continue? [y/N]"
  You: "y"

[safe-delete]
  ✓ Full SQL backup saved to ~/.opencode-trash/backups/sql/
  ✓ 003_add_tags.sql backed up to safekeeper
  ⚠ File deleted (database state not changed)
  ⚠ Warning: Database still has the tags column
  ✓ Logged to permanent-deletions.log
```

---

## Step 5: Alternative Scenario — Agent Initiated

```
User: "Clean up the db folder — it's a mess."

[Agent checks db/ folder]
[Agent thinks: "003_add_tags.sql is unused — let's delete it"]

[safe-delete] ⚠ Plan analysis: Agent is about to delete a migration file

┌──────────────────────────────────────────────────┐
│ ⚠ LANGUAGE-AWARE: Import Check                    │
│                                                   │
│ 003_add_tags.sql is referenced by:                │
│   • db/migrate.py:34 — migration runner           │
│   • alembic.ini — migration version               │
│   • db/versions/003_add_tags.py — migration class │
│                                                   │
│ Deleting will cause:                              │
│   • Migration runner will error                   │
│   • DB state will be inconsistent                 │
│                                                   │
│ [1] Skip (recommended)        [2] Backup+Delete   │
│ [3] Permanent                 [4] Find Alternative│
└──────────────────────────────────────────────────┘

User: "4"
Agent suggests:
  a) Ignore the file (leave in place)
  b) Archive to db/archived/
  c) Mark as deprecated in comments

User: "b"
✓ 003_add_tags.sql → db/archived/003_add_tags.sql
✓ Migration runner updated to skip archived/ folder
```

---

## Key Observations

1. **Integrity guard prevented a chain break** — Deleting a migration file while it's applied corrupts the database state
2. **The safest path was creating a reversal** — Not deleting at all, but neutralizing the effect
3. **Language-aware check caught the import graph** — The migration file was referenced by 3 other files
4. **Agent-initiated deletion was blocked** — The user said "clean up," not "delete migrations"

## Recovery Paths

| Scenario | Recovery |
|----------|----------|
| Deleted 003 | Restore from safekeeper, run `python manage.py migrate 002` |
| Reversal migration | `python manage.py migrate 005` rolls back |
| Full reset | `python manage.py migrate --fake 000` |
