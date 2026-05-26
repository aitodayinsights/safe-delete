# Function 17: Project Integrity Guard

## Purpose

Prevent agents from deleting files that would break the project structure — entry points, the only file of a certain type, migration histories, or files that maintain project coherence. This is the "obvious to a human, invisible to an agent" safety layer.

---

## Integrity Checks

### Check 1: Entry Point Protection

Detect if the target is a project entry point:

| Entry Point | Check | Risk |
|------------|-------|------|
| `main.py`, `app.py`, `cli.py` | Python entry point | +5 |
| `index.js`, `index.ts`, `index.jsx` | JS/TS entry point | +3 |
| `main.rs` | Rust entry point | +5 |
| `main.go` | Go entry point | +5 |
| `Main.java` | Java entry point | +5 |
| `index.html` | Web entry point | +4 |
| `next.config.js`, `vite.config.ts` | Build config entry | +3 |
| `Dockerfile` | Container entry | +3 |
| `docker-compose.yml` | Multi-container entry | +3 |

```bash
check_entry_point() {
    local name
    name=$(basename "$1")

    case "$name" in
        main.py|app.py|cli.py|manage.py)        return 0 ;;
        index.js|index.ts|index.jsx|index.tsx)  return 0 ;;
        main.rs)                                 return 0 ;;
        main.go)                                 return 0 ;;
        Main.java|Application.java)              return 0 ;;
        index.html|index.htm)                    return 0 ;;
        next.config.*|vite.config.*|webpack.config.*) return 0 ;;
        Dockerfile|docker-compose.*)             return 0 ;;
        *)                                       return 1 ;;
    esac
}
```

### Check 2: Only-Of-Its-Kind Detection

Detect if the target is the only file of its type in the project:

```bash
check_only_of_kind() {
    local ext
    ext="${1##*.}"

    local count
    count=$(find . -name "*.$ext" -not -path "./node_modules/*" \
            -not -path "./.git/*" 2>/dev/null | wc -l)

    if [ "$count" -eq 1 ]; then
        echo "ONLY:$ext"  # This is the only $ext file in the project
        return 0
    fi
    return 1
}
```

Examples:
- Only `.graphql` schema file → +3
- Only `.env.example` file → +2
- Only `.editorconfig` → +2
- Only `.nvmrc` or `.node-version` → +2
- Only `Procfile` → +3

### Check 3: Migration History Detection

Detect if the target is part of a database migration chain:

```bash
check_migration_file() {
    case "$1" in
        */migrations/*|*/migrate/*|*/alembic/*|*/db/migrate/*)
            echo "MIGRATION" ;;
        */sequelize/*|*/typeorm/*|*/prisma/*)
            echo "MIGRATION" ;;
        *)
            return 1 ;;
    esac
}
```

Migration files should NOT be deleted — they maintain the chain of schema changes. If you delete migration `003_add_users`, migration `004_add_posts` will fail.

| Migration Scenario | Action |
|-------------------|--------|
| Middle of chain (003 of 010) | BLOCKED — would break all later migrations |
| Last migration, not yet applied | Warn — suggest rollback first |
| Already applied | BLOCKED — would require manual DB fix |
| Reversible migration | Warn — suggest `migrate down` first |

### Check 4: Configuration Symlink Detection

Some config files depend on each other:

| File | Dependent Files |
|------|----------------|
| `tsconfig.json` | All `.ts` files, `next.config.js`, `jest.config.ts` |
| `.babelrc` / `babel.config.js` | All transpiled JS files |
| `.eslintrc*` | All linted files |
| `.prettierrc*` | All formatted files |
| `tailwind.config.js` | All Tailwind CSS files |
| `postcss.config.js` | All PostCSS-processed files |

### Check 5: Test Infrastructure Protection

```
jest.config.*        → +2 (all Jest tests depend on this)
pytest.ini           → +2 (all Python tests)
Cargo.toml [tests]   → +2 (all Rust tests)
go.mod test deps     → +2 (all Go tests)
```

### Check 6: Only Stylesheet Detection

```bash
# Is this the ONLY CSS/SCSS file in the project?
if [ "$ext" = "css" ] || [ "$ext" = "scss" ] || [ "$ext" = "less" ]; then
    total=$(find . -name "*.$ext" -not -path "./node_modules/*" \
            -not -path "./.git/*" 2>/dev/null | wc -l)
    if [ "$total" -le 2 ]; then
        # Only 1-2 stylesheets — very risky to delete
        echo "CRITICAL_STYLESHEET"
    fi
fi
```

---

## Risk Scoring for Integrity

| Condition | Risk Adjustment |
|-----------|----------------|
| Is an entry point | +5 |
| Is only file of its kind in project | +3 |
| Is a migration file | BLOCKED (inform user) |
| Is a config file with dependents | +3 |
| Is a test config | +2 |
| Is only stylesheet (≤2 total) | +4 |
| Is a lockfile (`package-lock.json`, `yarn.lock`) | +2 (regeneratable, but carefully) |
| Is a `.gitkeep` file | -1 (likely placeholder) |

---

## Integrity Guard Modal

```
┌─────────────────────────────────────────────────────────────┐
│ ⚠ INTEGRITY GUARD: This File Is Critical to Project Structure│
│                                                              │
│ Target: tsconfig.json                                        │
│                                                              │
│ This is:                                                     │
│   ✓ A build configuration file                                │
│   ✓ Required by 47 TypeScript files                           │
│   ✓ The only tsconfig in the project                          │
│                                                              │
│ ⚠ Deleting it will break ALL TypeScript compilation.          │
│                                                              │
│ [1] Skip — keep the file                   (recommended)      │
│ [2] Backup then delete (will break builds)                   │
│ [3] Rename to tsconfig.old.json (safe — no tool reads this)  │
│ [4] Find Alternative                                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Migration File Modal

```
┌─────────────────────────────────────────────────────────────┐
│ ⚠ INTEGRITY GUARD: This Is a Database Migration File         │
│                                                              │
│ Target: db/migrations/003_add_users_table.sql                 │
│                                                              │
│ Position: 3 of 10 in migration chain                          │
│ Status: Already applied in production                         │
│                                                              │
│ ⚠ Deleting this migration WILL:                               │
│   • Break migrations 004–010                                  │
│   • Require manual database repair                            │
│   • Cause deployment failures on fresh installs               │
│                                                              │
│ Would you like to:                                            │
│ [1] Skip — keep the migration              (recommended)      │
│ [2] Create a REVERSAL migration instead    (safe)             │
│ [3] Force delete (⚠ requires DB expertise to fix)            │
└─────────────────────────────────────────────────────────────┘
```

---

## Do Not

- Do NOT delete entry points without triple confirmation — they break the entire application
- Do NOT delete migration files from the middle of a chain — always create a reversal migration
- Do NOT delete the only stylesheet — the UI will have no styling
- Do NOT delete config files with explicit dependents — check `references` in config
- Do NOT delete lockfiles during an active install — wait for it to finish
- Do NOT delete all test files for a module — suggest keeping at least one smoke test
- Do NOT delete `.gitkeep` files without checking if the directory needs to exist
- Do NOT assume "only file of its kind" is safe to delete — it might be the canonical source
