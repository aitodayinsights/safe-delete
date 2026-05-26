# Function 08: Environment Detection

## Purpose

Detect whether the target belongs to development, staging, or production — before any delete. This prevents the #1 cause of data loss: deleting from the wrong environment.

## Detection Signals

Check ALL of these, not just one:

| Signal | Source | Dev Indicates | Prod Indicates |
|--------|--------|---------------|----------------|
| Connection string | `DATABASE_URL`, `DB_URL` | `localhost`, `127.0.0.1`, `dev.`, `staging.` | `prod.`, `.com`, `production` |
| Environment variable | `NODE_ENV`, `ENV`, `APP_ENV` | `development`, `dev`, `local` | `production`, `prod` |
| Cloud project ID | `GOOGLE_CLOUD_PROJECT`, `AWS_PROFILE` | `*-dev`, `*-staging` | `*-prod` |
| File path | Target path | Contains `dev/`, `test/` | Contains `production/`, `prod/`, `live/` |
| Git branch | `git branch --show-current` | `dev`, `feature/*` | `main`, `master`, `production` |
| Hostname | `HOSTNAME`, `COMPUTERNAME` | Local machine | Server name patterns |
| Kubernetes context | `kubectl config current-context` | `dev-*`, `staging-*` | `prod-*` |
| Firebase project | `.firebaserc`, `GOOGLE_APPLICATION_CREDENTIALS` | `*-dev` | `*-prod` |

## Detection Implementation

```powershell
function Get-Environment {
    $signals = @()

    # Check DB connection
    if ($env:DATABASE_URL) {
        if ($env:DATABASE_URL -match 'localhost|127\.0\.0\.1|\.dev\.|\.staging\.') { $signals += "dev" }
        if ($env:DATABASE_URL -match 'production|\.com|prod\.') { $signals += "production" }
    }

    # Check NODE_ENV
    if ($env:NODE_ENV -eq 'production') { $signals += "production" }
    if ($env:NODE_ENV -match 'dev|development|local') { $signals += "dev" }

    # Check cloud project
    if ($env:GOOGLE_CLOUD_PROJECT -match '-prod$') { $signals += "production" }
    if ($env:AWS_PROFILE -match 'prod') { $signals += "production" }

    # Check path
    if ($targetPath -match '\\production\\|\\prod\\|\\live\\') { $signals += "production" }

    # Conclusion
    if ($signals -contains "production") { return "production" }
    if ($signals -contains "staging" -and $signals -notcontains "dev") { return "staging" }
    return "dev"
}
```

## Environment → Risk Multiplier

| Detected Environment | Risk Multiplier | Effect |
|---------------------|----------------|--------|
| **Dev / Local** | 1× | Normal protocol |
| **Staging** | 1.5× (round up) | Extra care — staging may mirror production data |
| **Production** | +3 minimum | Hard minimum: production ops start at risk 4 even for small files |
| **Unknown** | 2× | Cannot verify safety — assume worst case |

## What to Present to User

When production is detected, present this prominently:

```markdown
## ⚠ PRODUCTION ENVIRONMENT DETECTED

Active connection: {DATABASE_URL or connection string}
Detected via: {list of signals}

Expected: {what user said / project default}
Actual: {what was detected}

[ ] This is correct — proceed with production protocol
[ ] This is WRONG — switch to dev/staging
[ ] Cancel — investigate connection settings
```

## Mismatch Alert

If the user says "this is dev" but the agent detects production, the agent MUST:

1. Block the delete
2. Present the mismatch evidence
3. Require explicit confirmation that production is intentional

## Do Not

- Do NOT rely on a single signal — check multiple sources
- Do NOT trust `NODE_ENV` alone — it's the easiest to misconfigure
- Do NOT skip environment detection for database operations
- Do NOT accept user's word "it's dev" without verifying
- Do NOT forget to check cloud credentials — they often point to prod
