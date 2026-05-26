# Function 07: Database Safety

## Purpose

Prevent catastrophic database operations — the #1 source of AI-caused data loss. This function applies to SQL databases (PostgreSQL, MySQL, SQLite, SQL Server, etc.) and NoSQL (Firestore, MongoDB, etc.).

## Core Rule

**Never execute a DROP, TRUNCATE, DELETE, or any destructive SQL without the full protocol below.**

## 6-Step Database Protocol

### Step 1: Detect Environment

Check the active database connection BEFORE any SQL — from every possible source:

```powershell
function Detect-DbEnvironment {
    $signals = @()

    # 1. Environment variables
    @('DATABASE_URL', 'DB_URL', 'DATABASE_HOST', 'PGHOST', 'MYSQL_HOST',
      'MONGODB_URI', 'REDIS_URL', 'ELASTICSEARCH_URL',
      'NODE_ENV', 'APP_ENV', 'RAILS_ENV', 'DJANGO_SETTINGS_MODULE',
      'GOOGLE_CLOUD_PROJECT', 'AWS_PROFILE', 'KUBERNETES_CONTEXT'
    ) | ForEach-Object {
        if ($env:$_) {
            $val = $env:$_
            if ($val -match 'prod|production|\.com|\.io') { $signals += "$_=PRODUCTION" }
            elseif ($val -match 'staging|stage') { $signals += "$_=STAGING" }
            elseif ($val -match 'dev|local|localhost|127\.0\.0\.1|\.test') { $signals += "$_=DEV" }
        }
    }

    # 2. Config files
    @("*.env", "*.env.*", "database.yml", "knexfile*", "prisma/schema.prisma",
      "application*.yml", "application*.properties", "config.json",
      ".env.production", ".env.staging", ".env.development"
    ) | ForEach-Object {
        Get-ChildItem -Path "." -Recurse -Filter $_ -Depth 2 -EA 0 | ForEach-Object {
            $content = Get-Content $_.FullName -Raw -EA 0
            if ($content -match 'production|prod|\.com') { $signals += "config:$($_.Name)=PRODUCTION" }
        }
    }

    # 3. Cloud credentials
    if ($env:GOOGLE_APPLICATION_CREDENTIALS) {
        $content = Get-Content $env:GOOGLE_APPLICATION_CREDENTIALS -Raw -EA 0
        if ($content -match '"project_id":\s*".*-prod"') { $signals += "GCP=PRODUCTION" }
    }

    # 4. Docker containers
    $compose = Get-ChildItem -Path "." -Filter "docker-compose*.yml" -Depth 1 -EA 0
    $compose | ForEach-Object {
        $content = Get-Content $_.FullName -Raw -EA 0
        if ($content -match 'POSTGRES_DB.*prod|MYSQL_DATABASE.*prod') { $signals += "docker:$($_.Name)=PRODUCTION" }
    }

    return $signals
}
```

**Present mismatch clearly:**

```markdown
### Environment Detection Results

| Source | Detected Value |
|--------|---------------|
| DATABASE_URL | postgresql://prod.example.com:5432/myapp → **PRODUCTION** |
| NODE_ENV | production → **PRODUCTION** |
| GOOGLE_CLOUD_PROJECT | myapp-prod → **PRODUCTION** |

⚠ All signals point to **PRODUCTION**. 
User stated: "this is dev".
Action: BLOCKED — mismatch requires resolution first.
```

---

### Step 2: Show Exact SQL

Present the exact SQL that will execute. Never modify it between showing and running.

```sql
-- Show this to the user verbatim:
DELETE FROM customers WHERE deleted_at IS NOT NULL;
-- Not: "cleaning up old customers"
-- Not: "removing soft-deleted records"
-- The EXACT SQL.
```

For DDL, also show the full statement:

```sql
DROP TABLE customers CASCADE;
ALTER TABLE orders DROP COLUMN customer_id;
```

---

### Step 3: EXPLAIN ANALYZE (NEW — Mandatory for DELETE/UPDATE)

Before any mutation, show the query execution plan. This reveals:
- Whether the query uses an index (without one, it locks the entire table)
- Estimated vs actual rows affected
- Execution time (more than a few seconds = production impact)

```sql
EXPLAIN ANALYZE DELETE FROM customers WHERE deleted_at IS NOT NULL;
```

**Present to user:**

```markdown
### Query Plan

| Node | Est. Rows | Actual Rows | Time |
|------|-----------|-------------|------|
| Delete on customers | 412,709 | — | — |
| Seq Scan (no index!) | 412,709 | 412,709 | 12.4s |

⚠ **Seq Scan detected** — no index on `deleted_at`. This will lock the table
  for ~12 seconds. All writes to `customers` will queue.
```

If no index on the WHERE column: show a warning and suggest creating one first.

---

### Step 4: Dry-Run Mode (NEW — Mandatory for DELETE/TRUNCATE)

**Before any real mutation, run a dry-run that shows everything without changing data.**

```sql
-- Dry-run: wrap in explicit ROLLBACK
BEGIN TRANSACTION;
  -- Count affected rows
  SELECT COUNT(*) AS rows_affected FROM customers WHERE deleted_at IS NOT NULL;

  -- Preview sample
  SELECT id, name, email, deleted_at FROM customers WHERE deleted_at IS NOT NULL LIMIT 10;

  -- Check what orders reference these customers
  SELECT COUNT(*) AS orphaned_orders FROM orders
  WHERE customer_id IN (SELECT id FROM customers WHERE deleted_at IS NOT NULL);

  -- Show the actual DELETE (but roll it back)
  DELETE FROM customers WHERE deleted_at IS NOT NULL;

  -- Verify count after delete
  SELECT COUNT(*) AS remaining_customers FROM customers;
ROLLBACK;  -- <-- dry-run: nothing changed
```

**Present the dry-run result:**

```markdown
### Dry-Run Results
| Metric | Value |
|--------|-------|
| Rows matching condition | 412,709 |
| Rows previewed | 10 |
| Orphaned orders if deleted | 2,847 |
| Table lock estimate | ~12s (seq scan) |
| **Rows actually changed** | **0 (dry-run, ROLLBACK executed)** |
| Rollback script generated | `fn-database.md` |
```

---

### Step 5: Count Affected Rows

```sql
-- ALWAYS run this first
SELECT COUNT(*) AS rows_affected FROM target_table WHERE condition;
```

Present the count prominently. If it's large (> 1000), flag it.

```markdown
⚠ **412,709 rows** will be deleted (33% of table)
```

**Rate-based warnings:**

| Rows | Warning |
|------|---------|
| 1–100 | Standard |
| 101–1,000 | "⚠ Over 100 rows — consider impact" |
| 1,001–10,000 | "⚠⚠ Mass delete — recommend backup + batch" |
| 10,001–100,000| "⚠⚠⚠ 10K+ rows — force batch mode (1000/batch, 1s pause)" |
| 100,000+ | "⚠⚠⚠ LARGE-SCALE DELETE — force production approval gate" |

**Batch mode for large deletes (auto-enforced > 10K rows):**

```sql
-- Instead of one giant DELETE, batch in chunks:
DO $$
DECLARE
    batch_size INT := 1000;
    affected INT;
BEGIN
    LOOP
        DELETE FROM target_table
        WHERE ctid IN (
            SELECT ctid FROM target_table
            WHERE condition
            LIMIT batch_size
        );
        GET DIAGNOSTICS affected = ROW_COUNT;
        COMMIT;  -- commit each batch to reduce lock pressure
        PERFORM pg_sleep(1);  -- 1 second pause between batches
        EXIT WHEN affected = 0;
    END LOOP;
END $$;
```

---

### Step 6: Preview Data

```sql
-- Show the user what they're deleting
SELECT * FROM target_table WHERE condition LIMIT 10;
```

For wide tables, select key columns only to keep the preview readable:

```sql
SELECT id, name, email, created_at, deleted_at, order_count
FROM customers WHERE condition LIMIT 10;
```

---

### Step 7: Check Dependencies

```sql
-- Foreign keys referencing this table
SELECT conname, conrelid::regclass AS referencing_table
FROM pg_constraint WHERE confrelid = 'target_table'::regclass;

-- Count dependent rows
SELECT count(*) FROM orders WHERE customer_id IN (SELECT id FROM target_table WHERE condition);

-- Check views/materialized views
SELECT schemaname, viewname FROM pg_views
WHERE definition ILIKE '%target_table%';

-- Check triggers
SELECT trigger_name, event_manipulation
FROM information_schema.triggers
WHERE event_object_table = 'target_table';

-- Check cron jobs / scheduled tasks that reference this table
SELECT jobname, schedule FROM cron.job WHERE jobdef ILIKE '%target_table%';

-- Check running queries that might be affected
SELECT pid, query, state, wait_event
FROM pg_stat_activity WHERE query ILIKE '%target_table%' AND state = 'active';
```

---

### Step 8: Auto-Generate Rollback Script (NEW)

Before executing any mutation, generate the exact rollback script and show it to the user:

```sql
-- ══════════════════════════════════════════════
-- ROLLBACK SCRIPT (auto-generated)
-- If something goes wrong, run this to undo.
-- ══════════════════════════════════════════════

-- FOR CURRENT TRANSACTION (if not yet committed):
ROLLBACK;

-- FOR COMMITTED DELETE (restore from backup table):
INSERT INTO customers SELECT * FROM customers_bak_20260522;

-- FOR COMMITTED DELETE (restore from CSV):
-- \COPY customers FROM './backup/customers_20260522.csv' CSV HEADER;

-- FOR DROPPED TABLE (restore from backup table):
INSERT INTO customers SELECT * FROM customers_bak_20260522;
-- Re-create indexes:
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_customers_deleted_at ON customers(deleted_at);
-- Re-create FKs (if cascade dropped):
ALTER TABLE orders ADD CONSTRAINT fk_customer
  FOREIGN KEY (customer_id) REFERENCES customers(id);
```

**Store the rollback script to a file BEFORE executing the delete:**

```powershell
$rollbackScript = @"
-- ROLLBACK for deletion on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
ROLLBACK;
-- Or if committed:
INSERT INTO target_table SELECT * FROM target_table_bak_YYYYMMDD;
"@

$rollbackPath = "$env:USERPROFILE\.opencode-trash\rollback-$(Get-Date -Format 'yyyy-MM-dd_HHmmss').sql"
Set-Content -Path $rollbackPath -Value $rollbackScript
Write-Host "⚠ Rollback script saved to: $rollbackPath"
```

---

### Step 9: Backup, Transaction, Execute

```sql
-- Backup affected rows
CREATE TABLE target_table_bak_YYYYMMDD AS
SELECT * FROM target_table WHERE condition;

-- Or CSV export
\COPY (SELECT * FROM target_table WHERE condition) TO 'backup.csv' CSV HEADER;

-- WRAP IN TRANSACTION
BEGIN TRANSACTION;
DELETE FROM target_table WHERE condition;
-- ROLLBACK; -- if something looks wrong
-- COMMIT;   -- only after user re-confirms
```

**After DELETE execution, verify:**

```sql
SELECT COUNT(*) AS rows_now FROM target_table;
-- Compare with pre-delete count to confirm correct number removed
```

---

## Production Approval Gate (NEW)

For **production** database operations with risk >= 8, enforce an approval gate:

```yaml
production_approval_gate:
  risk_required: 8+      # Only triggers for high-risk prod ops
  approvals_required: 2  # Two people must approve
  approval_method: |
    Agent presents the full plan (SQL, row count, dry-run result,
    rollback script) to the user. User must:
    1. First approval: "I have reviewed the impact and approve"
    2. Second approval: "I confirm again this is the correct action"
  time_window:
    allowed_hours: "09:00–17:00 UTC"  # No production deletes outside business hours
    reason: "If something breaks, team must be available to fix"
  wait_period: "5 minutes"  # Mandatory cooldown between approval and execution
```

**Time-window enforcement:**

```powershell
$currentHour = (Get-Date).Hour
if ($currentHour -lt 9 -or $currentHour -ge 17) {
    Write-Host @"
⚠ BLOCKED: Production delete outside business hours (09:00–17:00)

Current time: $(Get-Date -Format 'HH:mm')
Allowed window: 09:00–17:00 UTC

Reason: If this operation breaks something, your team must be available
to respond. Schedule this for business hours or get explicit override.

Override: User must confirm "I accept the risk of out-of-hours operation"
"@
}
```

---

## DDL Safety (DROP TABLE, ALTER, etc.)

```sql
-- EXTRA checks for DDL operations:

-- 1. Check all FKs
SELECT conname, conrelid::regclass AS referencing_table
FROM pg_constraint WHERE confrelid = 'target_table'::regclass;

-- 2. Check views
SELECT viewname FROM pg_views WHERE definition ILIKE '%target_table%';

-- 3. Check triggers/functions
SELECT trigger_name FROM information_schema.triggers
WHERE event_object_table = 'target_table';

-- 4. Check indexes
SELECT indexname FROM pg_indexes WHERE tablename = 'target_table';

-- 5. Check if table has data
SELECT COUNT(*) FROM target_table;

-- 6. Check replication status
SELECT slot_name, active, pg_wal_lsn_diff(
  pg_current_wal_lsn(), restart_lsn
) AS lag_bytes FROM pg_replication_slots
WHERE database = 'target_database';

-- 7. Only then DROP (wrapped in transaction)
BEGIN;
DROP TABLE target_table CASCADE;
-- ROLLBACK;
```

---

## NoSQL Safety (Firestore, MongoDB)

```powershell
# Firestore — always export before delete
firebase firestore:export gs://project-backups/collection_20260522 --collection-ids=target_collection

# MongoDB — mongodump first
mongodump --collection=target_collection --out=./backup_20260522

# Check document count
db.target_collection.countDocuments({condition})

# Preview
db.target_collection.find({condition}).limit(10)

# MongoDB — use bulkWrite with ordered:false for controlled batch delete
var batch = db.target_collection.find({condition}).limit(1000)
var ops = batch.map(doc => ({ deleteOne: { filter: { _id: doc._id } } }))
db.target_collection.bulkWrite(ops, { ordered: false })
```

---

## Schema Version Check (NEW)

Before deleting a migration file or running a migration, verify it hasn't been applied:

```sql
-- Check if migration was already applied
SELECT * FROM migrations WHERE filename LIKE '%20260520_add_customers%';

-- Check migration table exists at all
SELECT EXISTS (
  SELECT FROM information_schema.tables
  WHERE table_name = 'migrations' OR table_name = '_migrations'
);

-- If migration was applied, warn:
-- ⚠ This migration was already applied to production.
-- Deleting the file will NOT revert the schema.
-- You need a DOWN migration, not a file deletion.
```

---

## Query Impact Estimation (NEW)

Before running any heavy query, estimate the impact on running processes:

```sql
-- Current database load
SELECT count(*) AS active_queries,
       count(*) FILTER (WHERE state = 'active') AS running,
       count(*) FILTER (WHERE wait_event IS NOT NULL) AS waiting
FROM pg_stat_activity WHERE datname = current_database();

-- Table statistics
SELECT relname, n_live_tup, n_dead_tup,
       round(100 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 2) AS dead_pct
FROM pg_stat_user_tables WHERE relname = 'target_table';

-- Lock analysis
SELECT relation::regclass, mode, granted
FROM pg_locks WHERE relation = 'target_table'::regclass;
```

---

## Complete Production Approval Workflow (NEW)

For risk >= 8 on production databases, this full workflow must be completed:

```markdown
### PRODUCTION DATABASE APPROVAL GATE

**Phase 1 — Preparation (Agent does automatically)**
  - [x] Environment confirmed: PRODUCTION
  - [x] SQL generated: `DELETE FROM customers WHERE ...`
  - [x] Row count: 412,709
  - [x] Dry-run executed: ROLLBACK (0 rows changed)
  - [x] EXPLAIN ANALYZE: Seq Scan detected — 12s lock
  - [x] Dependencies: 2,847 orphaned orders, 3 views, 1 FK
  - [x] Rollback script generated
  - [x] Backup table created: `customers_bak_20260522`

**Phase 2 — Approval (User must provide)**
  - [ ] First approval: "I have reviewed the plan" (sign)
  - [ ] Impact acknowledgment: "I understand the risks" (sign)
  - [ ] Second approval: "Proceed with execution" (sign)

**Phase 3 — Cooldown (5 minute mandatory wait)**
  - [ ] Waiting 5 minutes... (re-verify connection stability)
  - [ ] Re-check that backup table still exists
  - [ ] Re-check no other team member started this operation

**Phase 4 — Execute**
  - [ ] BEGIN TRANSACTION
  - [ ] DELETE FROM customers WHERE ...
  - [ ] Verify row count
  - [ ] COMMIT or ROLLBACK
```

---

## Do Not

- Do NOT run any SQL without showing the exact query first
- Do NOT skip `SELECT COUNT(*)` — the row count changes decisions
- Do NOT skip `EXPLAIN ANALYZE` — the query plan reveals hidden dangers
- Do NOT skip dry-run — always rollback the first execution
- Do NOT skip transaction wrapping — ROLLBACK must be possible
- Do NOT run production deletes outside business hours without override
- Do NOT skip generating the rollback script BEFORE executing
- Do NOT delete > 10K rows in one shot — batch mode is mandatory
- Do NOT trust a single `NODE_ENV` — verify the actual connection string
- Do NOT skip dependency analysis — deleted customers may have active orders
- Do NOT skip the 5-minute cooldown for production operations
- Do NOT ignore running `pg_stat_activity` — you might lock active queries
