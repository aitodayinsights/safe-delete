# Function 16: Language-Aware Import Guard

## Purpose

Analyze import/require graphs before deleting source code files. Prevents deletion of files that are actively imported by other modules — the "silent breakage" problem where deleting a file looks safe but breaks 20 other files.

---

## Language Detection

Detect the programming language from file extension:

```bash
detect_language() {
    case "$1" in
        *.py)      echo "python" ;;
        *.js|*.jsx|*.mjs|*.cjs) echo "javascript" ;;
        *.ts|*.tsx|*.mts|*.cts) echo "typescript" ;;
        *.rs)      echo "rust" ;;
        *.go)      echo "go" ;;
        *.java)    echo "java" ;;
        *.kt|*.kts) echo "kotlin" ;;
        *.swift)   echo "swift" ;;
        *.rb)      echo "ruby" ;;
        *.php)     echo "php" ;;
        *.c|*.h)   echo "c" ;;
        *.cpp|*.hpp|*.cc|*.cxx) echo "cpp" ;;
        *)         echo "unknown" ;;
    esac
}
```

---

## Import Analysis Per Language

### Python

```bash
# Check if any file imports this module
check_python_imports() {
    local module_name
    module_name=$(basename "$1" .py)

    # Check direct imports
    grep -rl "^import $module_name\b\|^from $module_name import\|^from $module_name\." \
        --include="*.py" . 2>/dev/null || true

    # Check __init__.py re-exports
    grep -rl "from \.$module_name import\|from $module_name import" \
        --include="__init__.py" . 2>/dev/null || true
}
```

### JavaScript / TypeScript

```bash
check_js_imports() {
    local module_path="$1"
    local module_name
    module_name=$(basename "$module_path" | sed 's/\.[^.]*$//')

    # Remove index. prefix for directory imports
    if [ "$module_name" = "index" ]; then
        module_name=$(basename "$(dirname "$module_path")")
    fi

    # Relative imports
    grep -rl "from ['\"].*\/$module_name['\"]\|require(['\"].*\/$module_name['\"]" \
        --include="*.{js,jsx,ts,tsx,mjs,cjs}" . 2>/dev/null || true

    # Side-effect imports
    grep -rl "import ['\"].*\/$module_name['\"]" \
        --include="*.{js,jsx,ts,tsx}" . 2>/dev/null || true

    # Dynamic imports
    grep -rl "import(['\"].*\/$module_name['\"])\|require\.ensure" \
        --include="*.{js,jsx,ts,tsx}" . 2>/dev/null || true
}
```

### Rust

```bash
check_rust_imports() {
    local module_name
    module_name=$(basename "$1" .rs)

    # mod declarations (in parent mod.rs or lib.rs)
    grep -rl "^mod $module_name\b" --include="mod.rs" --include="lib.rs" \
        . 2>/dev/null || true

    # use statements
    grep -rl "use .*::$module_name\|use $module_name::" \
        --include="*.rs" . 2>/dev/null || true
}
```

### Go

```bash
check_go_imports() {
    local pkg_path="$1"
    local pkg_name
    pkg_name=$(head -1 "$1" | grep "^package " | awk '{print $2}' 2>/dev/null)

    if [ -n "$pkg_name" ]; then
        # Imports of this package
        grep -rl "\"$(basename "$(dirname "$1")")\"" \
            --include="*.go" . 2>/dev/null || true
    fi
}
```

### Java / Kotlin

```bash
check_jvm_imports() {
    local class_name
    class_name=$(basename "$1" | sed 's/\.[^.]*$//')

    grep -rl "import .*\.$class_name;" \
        --include="*.java" --include="*.kt" . 2>/dev/null || true
}
```

---

## Risk Scoring for Imports

| Importers Found | Risk Adjustment | Action |
|----------------|----------------|--------|
| 0 importers | 0 | Normal deletion flow |
| 1–2 importers | +2 | Show importer names; offer to update imports |
| 3–5 importers | +3 | Show all importers; suggest refactor first |
| 6+ importers | +4 | Block unless user explicitly overrides |
| Is `__init__.py` in a package | +3 | Package re-export — high impact |
| Is `mod.rs` / `lib.rs` | +5 | Rust module root — very high impact |
| Is `index.js` / `index.ts` | +3 | Module entry point |
| Is `main.py` / `main.rs` / `main.go` | +5 | Application entry point |

---

## Language-Aware Modal

```
┌─────────────────────────────────────────────────────────────┐
│ ⚠ LANGUAGE-AWARE: File Imported by 4 Other Files            │
│                                                              │
│ Target: src/utils/helpers.ts                                 │
│                                                              │
│ Imported by:                                                  │
│   src/api/users.ts       — import { validate } from './utils'│
│   src/api/orders.ts      — import { formatDate } from './..' │
│   src/services/auth.ts   — import { hashPassword } from ..'  │
│   src/middleware/log.ts  — import { sanitize } from '../..'  │
│                                                              │
│ If you delete helpers.ts, these files will BREAK:            │
│   • src/api/users.ts — line 3                                │
│   • src/api/orders.ts — line 5                               │
│   • src/services/auth.ts — line 2                            │
│   • src/middleware/log.ts — line 8                           │
│                                                              │
│ [1] Backup then delete + auto-update imports  ✓ safest       │
│ [2] Backup then delete (manual update needed)                │
│ [3] Skip — don't touch                    (recommended)      │
│ [4] Find Alternative — extract, deprecate, or inline         │
└─────────────────────────────────────────────────────────────┘
```

---

## Auto-Update Imports

When the user chooses [1], safe-delete can attempt to update import references:

```python
# Python: Update all imports
# helpers.py → helpers_deprecated.py
# import helpers → import helpers_deprecated
```

```bash
# JS/TS: Replace import paths
# helpers.ts → helpers_deprecated.ts
sed -i 's|from '\''\./helpers'\''|from '\''./helpers_deprecated'\''|g' src/**/*.{ts,tsx}
sed -i 's|from '\''\./helpers/'\''|from '\''./helpers_deprecated'\''|g' src/**/*.{ts,tsx}
```

Or simpler: rename the file to `.deleted` instead of removing it:

```bash
mv helpers.ts helpers.ts.deleted
# All imports still resolve (file exists) but it's clearly marked
```

---

## Config File Protection

Certain config files have implicit import relationships:

| File | Implicit Importers | Protection |
|------|-------------------|------------|
| `tsconfig.json` | ALL TypeScript files | +3 |
| `package.json` | npm/node ecosystem | +4 |
| `Cargo.toml` | ALL Rust files | +4 |
| `go.mod` | ALL Go files | +4 |
| `pom.xml` / `build.gradle` | ALL JVM files | +4 |
| `Dockerfile` | CI/CD pipeline | +2 |
| `.env` | Application config | +3 |
| `Makefile` | Development workflow | +2 |

---

## Do Not

- Do NOT delete a file without checking its import graph
- Do NOT treat "no imports found" as "safe to delete" for config files
- Do NOT delete the only implementation file in a module
- Do NOT delete `__init__.py` without checking the package tree
- Do NOT delete test entry point files (pytest config, jest.config, etc.)
- Do NOT promise auto-import-update for complex refactors — ask first
- Do NOT skip import check for `.d.ts` files — they have implicit consumers
