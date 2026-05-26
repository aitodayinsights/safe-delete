# Safe Delete — Example Scenarios

Each scenario walks through: Discovery → Risk scoring → Impact analysis → User presentation → Execution.

## By Risk Level

| # | Scenario | Risk | Context | What Happens |
|---|----------|------|---------|-------------|
| 01 | **Orphaned component cleanup** | 3/10 | React component, single file | Single question → Recycle Bin |
| 02 | **Bulk build artifacts** | 5/10 | 230 files, build output | Summary → Backup → Confirm → Batch Recycle Bin |
| 03 | **SQL migration rollback** | 7/10 | Database migration, staging | Full impact → Zip backup → Double confirm → Down migration alternative |
| 04 | **Firestore collection drop** | 8/10 | Cloud NoSQL, prod credentials | Export first → Zip dump → Triple confirm → TTL policy alternative |
| 05 | **Production customer data** | 9/10 | PostgreSQL, 412K rows | Full audit → BLOCKED → Archive strategy |
| 06 | **Stripe API key rotation** | 9/10 | .env.production, running services | Full audit → Cooldown strategy → Safe rotation alternative |

## By Trigger Type

| # | Scenario | Trigger | Agent Decision |
|---|----------|---------|----------------|
| 07 | **"My C drive is full"** | Concealed (free up space) | Scan → Categorize → Curate → Ask → Delete chosen |
| 08 | **"Just delete it all" (frustrated)** | Direct + frustrated | Pause → "I understand" → Block vague → Present curated options |
| 09 | **"Clean up temp files"** | Indirect (clean up) | Clarify scope → Present sizes → Confirm → Recycle Bin |
| 10 | **"/instant delete node_modules"** | Instant mode | Show warning → User confirms → Permanent delete (no recovery) |
