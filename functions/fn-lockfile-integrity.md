# Lockfile Integrity — Package Manager & Manifest Guard

## Purpose

Before allowing deletion of files inside package-manager-controlled directories (`node_modules/`, `vendor/`, `packages/`, `.go/`, `target/`), verify that the deletion won't break the project's manifest-lockfile contract. Deleting a package file without updating the manifest leaves the lockfile stale, causing undetected build failures.

---

## When This Activates

- Step 3h in workflow: after skill integration gate (3g), before risk scoring (4)
- Only when target is inside a known package manager directory
- Target directories: `node_modules/`, `vendor/`, `packages/`, `vendor/bundle/`, `.go/`, `target/`, `site-packages/`, `Lib/site-packages/`, `bower_components/`, `.pnpm/`

---

## Detection by Package Manager

### npm / pnpm / yarn (Node.js)

| Manifest | Lockfile | Delete Context |
|----------|----------|----------------|
| `package.json` | `package-lock.json` | Deleting from `node_modules/` |
| `package.json` | `pnpm-lock.yaml` | Deleting from `node_modules/` or `.pnpm/` |
| `package.json` | `yarn.lock` | Deleting from `node_modules/` |

**Check:**
```bash
# Is the package declared?
grep -q "\"$PACKAGE_NAME\"" package.json && echo "DECLARED" || echo "NOT_DECLARED"
```

**Action:**
- If declared in manifest: `BLOCK` — "This package is declared in `package.json`. Remove it first: `pnpm remove <pkg>` / `npm uninstall <pkg>`"
- If NOT declared (orphan/transitive): `ALLOW with warning` — "Orphan dependency (not in manifest). Lockfile will be stale."

### Rust (Cargo)

| Manifest | Lockfile | Delete Context |
|----------|----------|----------------|
| `Cargo.toml` | `Cargo.lock` | Deleting from `target/` or `~/.cargo/` |

**Check:**
```bash
# Is the crate declared?
grep -q "$CRATE_NAME" Cargo.toml && echo "DECLARED" || echo "NOT_DECLARED"
```

**Action:**
- If declared: `BLOCK` — "Remove from Cargo.toml first: `cargo remove <crate>`"
- If NOT declared: `ALLOW with warning`

### Go

| Manifest | Lockfile | Delete Context |
|----------|----------|----------------|
| `go.mod` | `go.sum` | Deleting from `$GOPATH/pkg/mod/` or `vendor/` |

**Check:**
```bash
# Is the module required?
grep -q "$MODULE_PATH" go.mod && echo "REQUIRED" || echo "NOT_REQUIRED"
```

**Action:**
- If required: `BLOCK` — "Remove from go.mod first: `go get <module>@none`"
- If NOT required: `ALLOW with warning`

### PHP (Composer)

| Manifest | Lockfile | Delete Context |
|----------|----------|----------------|
| `composer.json` | `composer.lock` | Deleting from `vendor/` |

**Check:**
```json
composer show --direct 2>/dev/null | grep -q "$PACKAGE" && echo "DECLARED" || echo "NOT_DECLARED"
```

**Action:**
- If declared: `BLOCK` — "Remove from composer.json first: `composer remove <pkg>`"
- If NOT declared: `ALLOW with warning`

### Python (pip/pipenv/poetry)

| Manifest | Lockfile | Delete Context |
|----------|----------|----------------|
| `requirements.txt` / `Pipfile` / `pyproject.toml` | `Pipfile.lock` / `poetry.lock` | Deleting from `site-packages/`, `Lib/site-packages/`, `.venv/` |

**Check:**
```bash
grep -qi "$PACKAGE" requirements.txt 2>/dev/null && echo "DECLARED" || echo "NOT_DECLARED"
grep -qi "$PACKAGE" pyproject.toml 2>/dev/null && echo "DECLARED" || echo "NOT_DECLARED"
```

**Action:**
- If declared: `BLOCK` — "Remove from requirements.txt first, then `pip uninstall <pkg>`"
- If NOT declared: `ALLOW with warning`

### Workspace / Monorepo Detection

```bash
# Detect workspace root
test -f pnpm-workspace.yaml && echo "PNPM_WORKSPACE"
test -f lerna.json && echo "LERNA"
test -f nx.json && echo "NX"
test -f package.json && grep -q '"workspaces"' package.json && echo "YARN_WORKSPACES"
```

**Additional check:** If deleting from a workspace package, check if OTHER workspace packages depend on it:
```bash
grep -r "\"@scope/$PACKAGE\"" packages/*/package.json --include="package.json" | grep -v "$TARGET_PACKAGE"
```

---

## Risk Modifiers

| Condition | Risk Modifier |
|-----------|---------------|
| Declared in manifest + lockfile exists | +3 (lockfile will be stale) |
| Declared in manifest + no lockfile | +2 (manifest out of sync) |
| Transitive dependency (orphan) | +1 (may break transitive consumers) |
| Workspace package with 0 consumers | 0 (safe to delete) |
| Workspace package with 1+ consumers | +4 (multi-package breakage) |
| Monorepo root config file | +5 (blocked, affects all packages) |

---

## Suggested Alternatives

Instead of manual deletion from package-managed directories, suggest:

| Scenario | Correct Action |
|----------|---------------|
| Remove npm dependency | `npm uninstall <pkg>` or `pnpm remove <pkg>` |
| Remove Rust crate | `cargo remove <crate>` |
| Remove Go module | `go get <module>@none` then `go mod tidy` |
| Remove PHP package | `composer remove <pkg>` |
| Remove Python package | `pip uninstall <pkg>` |
| Delete workspace package | Remove from workspace config + unlink consumers |
| Delete vendor dir contents | `cargo clean` / `rm -rf vendor && composer install` |

---

## Modal Integration

When lockfile integrity is breached:

```
┌──────────────────────────────────────────────────────────────┐
│ ⚠ LOCKFILE INTEGRITY VIOLATION                               │
│                                                              │
│ Target:  node_modules/express/lib/                           │
│ Manifest: package.json (declares "express": "^4.18.0")       │
│ Lockfile: package-lock.json (will be stale)                   │
│                                                              │
│ Deleting this directly will corrupt your lockfile.            │
│                                                              │
│ [1] Use correct tool: pnpm remove express                     │
│ [2] Delete anyway + regenerate lockfile (may break build)    │
│ [3] Skip — don't touch this                                  │
└──────────────────────────────────────────────────────────────┘
```

---

## Do Not

- Allow deletion of manifest-declared packages without warning
- Forget to check the lockfile — it's the real source of truth
- Assume all `node_modules/` contents are safe to delete naked
- Delete workspace packages without checking consumers
- Suggest `rm -rf node_modules` as a fix — that's a last resort
- Let the user delete a package that another workspace package depends on
- Ignore transitive dependencies — they can still cause breakage
- Skip lockfile check for orphan packages — they may still be in the lockfile
