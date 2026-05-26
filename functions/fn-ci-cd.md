# Function 13: CI/CD Pipeline Safety

## Purpose

Detect when safe-delete is running in a CI/CD pipeline (non-interactive environment) and adjust behaviour automatically — no terminal modals, no user prompts. Provide safe defaults, rollback automation, and audit-compatible output.

---

## Detection Signals

Safe-Delete checks these signals to determine if it's in a CI/headless environment:

| Signal | Check | Priority |
|--------|-------|----------|
| `CI` env var | `$env:CI -eq "true"` | Highest |
| `GITHUB_ACTIONS` | `$env:GITHUB_ACTIONS -eq "true"` | High |
| `GITLAB_CI` | `$env:GITLAB_CI -eq "true"` | High |
| `JENKINS_URL` | `$env:JENKINS_URL` exists | High |
| No TTY | `[Console]::IsOutputRedirected` or `! -t 1` | Medium |
| `TERM=dumb` | `$env:TERM -eq "dumb"` | Medium |
| `SAFE_DELETE_CI` | `$env:SAFE_DELETE_CI -eq "true"` (manual override) | Highest |

```powershell
function Test-IsCI {
    $ciSignals = @(
        $env:CI,
        $env:GITHUB_ACTIONS,
        $env:GITLAB_CI,
        $env:JENKINS_URL,
        $env:TF_BUILD,           # Azure DevOps
        $env:CIRCLECI,
        $env:TRAVIS,
        $env:BITBUCKET_COMMIT,
        $env:CODEBUILD_BUILD_ID  # AWS CodeBuild
    )
    $isCI = ($ciSignals | Where-Object { $_ -eq "true" -or $null -ne $_ }) -ne $null

    if (-not $isCI) {
        $isCI = -not [Console]::IsOutputRedirected -eq $false -or $env:TERM -eq "dumb"
    }
    return $isCI
}
```

```bash
# Bash equivalent
is_ci() {
    [ "${CI:-}" = "true" ] ||
    [ "${GITHUB_ACTIONS:-}" = "true" ] ||
    [ "${GITLAB_CI:-}" = "true" ] ||
    [ -n "${JENKINS_URL:-}" ] ||
    [ "${TF_BUILD:-}" = "true" ] ||
    [ "${CIRCLECI:-}" = "true" ] ||
    [ "${TRAVIS:-}" = "true" ] ||
    [ -n "${BITBUCKET_COMMIT:-}" ] ||
    [ -n "${CODEBUILD_BUILD_ID:-}" ] ||
    [ ! -t 1 ] ||
    [ "${TERM:-}" = "dumb" ]
}
```

---

## Behaviour in CI Mode

When CI is detected, the interactive modal is **skipped** and replaced with automatic behaviour:

| Risk Level | CI Behaviour |
|------------|-------------|
| 1–3 (Low) | Auto → Recycle Bin. No output. |
| 4–5 (Medium) | Auto → Backup + Recycle Bin. Log as `[CI] auto-backup`. |
| 6–7 (High) | Auto → Backup + Recycle Bin. Log with summary. Emit warning. |
| 8–9 (Critical) | **BLOCKED** — abort operation. Emit error. Require `SAFE_DELETE_CI=true` env var to override. |
| 10 (Catastrophic) | **BLOCKED** — always blocked. Exit with error code. |

### CI Decision Flow

```
CI detected
    │
    ├── Risk 1-5: → Auto backup → Recycle Bin → Continue
    │
    ├── Risk 6-7: → Auto backup (zip) → Recycle Bin
    │              → Log warning: "[CI] File deleted: path (risk 6)"
    │              → Continue
    │
    ├── Risk 8-9: → BLOCKED
    │              → Log error: "[CI] BLOCKED: path (risk 8)"
    │              → Check SAFE_DELETE_CI=true
    │              │   ├── Set → Auto backup → Recycle Bin → Continue
    │              │   └── Not set → Exit 1
    │
    └── Risk 10:  → BLOCKED FOREVER
                  → Log critical: "[CI] CATASTROPHIC BLOCK: path (risk 10)"
                  → Exit 1
```

---

## CI Output Format

In CI mode, all output should be machine-parseable:

```
[CI] [safe-delete] ACTION=backup  TARGET="path" RISK=6 DEST="backup-path"
[CI] [safe-delete] ACTION=delete  TARGET="path" METHOD=recycle STATUS=ok
[CI] [safe-delete] ACTION=block   TARGET="path" RISK=9 REASON="CI block risk≥8"
```

This format can be consumed by:
- GitHub Actions annotations
- GitLab CI artifacts
- Jenkins log parsers
- Custom monitoring dashboards

---

## Rollback PR Automation

For GitHub Actions specifically, safe-delete can emit a rollback PR instruction:

```yaml
# .github/workflows/ci.yml
- name: Run safe-delete
  run: |
    ./scripts/validate.sh
  env:
    SAFE_DELETE_CI: "true"
  continue-on-error: true

- name: Create rollback PR if deletions occurred
  if: failure()
  run: |
    gh pr create \
      --base main \
      --head rollback/restore-deleted-files \
      --title "Rollback: Restore files deleted by safe-delete" \
      --body "Files were blocked or backed up during CI. This PR restores them."
```

---

## Headless Mode (No Terminal)

When running in a headless environment (SSH, Docker, CI runner, daemon):

| Feature | Behaviour |
|---------|-----------|
| Modal | Skipped — auto-default based on risk |
| Confirmations | Skipped — risk-based auto-action |
| Backup | Always performed (no size prompt) |
| Safekeeper | Active (hidden backup always made) |
| Audit | Writes to `deletion-log.txt` |
| Recovery script | Generated automatically |
| Exit code | 0 = success, 1 = blocked/error |

---

## Manual CI Override

Users can force CI mode or override CI blocks:

```bash
# Force CI mode (even in terminal)
export SAFE_DELETE_CI=true

# Allow risk 8-9 deletions in CI (use with caution)
export SAFE_DELETE_ALLOW_RISK8=true
export SAFE_DELETE_ALLOW_RISK9=true

# Set CI output format
export SAFE_DELETE_CI_FORMAT=github  # github, gitlab, json, silent
```

---

## Do Not

- Do NOT present interactive modal in CI mode — use auto-defaults
- Do NOT allow risk 10 deletions in any CI mode — always block
- Do NOT exit 0 on blocked operations — use non-zero exit code
- Do NOT skip backup in CI mode — always back up before any delete
- Do NOT assume CI = no audit — always write to deletion-log.txt
- Do NOT require user confirmation for CI operations — use risk-based defaults
- Do NOT let `SAFE_DELETE_ALLOW_RISK9` bypass safekeeper — safekeeper is mandatory
