#!/usr/bin/env bash
# Test: Safe-Delete Skill Structure
# Verifies all required files exist and cross-references are consistent

set -euo pipefail

SKILL_DIR="${1:-$(dirname "$(dirname "$(realpath "$0")")")}"
PASS=0
FAIL=0
WARN=0

green() { printf "\033[32m%s\033[0m\n" "$1"; }
red() { printf "\033[31m%s\033[0m\n" "$1"; }
yellow() { printf "\033[33m%s\033[0m\n" "$1"; }

check() {
    local desc="$1" path="$2"
    if [ -f "$SKILL_DIR/$path" ] || [ -d "$SKILL_DIR/$path" ]; then
        green "  ✓ $desc"
        PASS=$((PASS + 1))
    else
        red "  ✗ $desc (missing: $path)"
        FAIL=$((FAIL + 1))
    fi
}

check_content() {
    local desc="$1" path="$2" pattern="$3"
    if grep -q "$pattern" "$SKILL_DIR/$path" 2>/dev/null; then
        green "  ✓ $desc"
        PASS=$((PASS + 1))
    else
        red "  ✗ $desc ($path missing: $pattern)"
        FAIL=$((FAIL + 1))
    fi
}

echo "========================================"
echo " Safe-Delete Structure Test"
echo "========================================"
echo ""

# ── Root files ──
echo "--- Root files ---"
check "README.md" "README.md"
check "LICENSE" "LICENSE"
check "CONTRIBUTING.md" "CONTRIBUTING.md"
check "CHANGELOG.md" "CHANGELOG.md"
check "version.json" "version.json"
check "Makefile" "Makefile"

# ── Core skill files ──
echo ""
echo "--- Core skill files ---"
check "SKILL.md" "SKILL.md"
check "behaviour.md" "behaviour.md"
check "commands.md" "commands.md"

# ── Functions ──
echo ""
echo "--- Functions ---"
check "fn-audit.md" "functions/fn-audit.md"
check "fn-backup.md" "functions/fn-backup.md"
check "fn-database.md" "functions/fn-database.md"
check "fn-delete-methods.md" "functions/fn-delete-methods.md"
check "fn-delete-modal.md" "functions/fn-delete-modal.md"
check "fn-emergency.md" "functions/fn-emergency.md"
check "fn-environment.md" "functions/fn-environment.md"
check "fn-instant-mode.md" "functions/fn-instant-mode.md"
check "fn-permanent-delete.md" "functions/fn-permanent-delete.md"
check "fn-recovery.md" "functions/fn-recovery.md"
check "fn-risk-scoring.md" "functions/fn-risk-scoring.md"
check "fn-safekeeper.md" "functions/fn-safekeeper.md"
check "fn-ci-cd.md" "functions/fn-ci-cd.md"
check "fn-git-aware.md" "functions/fn-git-aware.md"
check "fn-process-aware.md" "functions/fn-process-aware.md"
check "fn-language-aware.md" "functions/fn-language-aware.md"
check "fn-integrity-guard.md" "functions/fn-integrity-guard.md"
check "INDEX.md" "functions/INDEX.md"

# ── References ──
echo ""
echo "--- References ---"
check "cheatsheet.md" "references/cheatsheet.md"

# ── Scripts ──
echo ""
echo "--- Scripts ---"
check "install.sh" "scripts/install.sh"
check "validate.sh" "scripts/validate.sh"
check "test-prereqs.sh" "scripts/test-prereqs.sh"
if [ -x "$SKILL_DIR/scripts/install.sh" ]; then
    green "  ✓ install.sh is executable"
    PASS=$((PASS + 1))
else
    yellow "  ⚠ install.sh not executable"
    WARN=$((WARN + 1))
fi

# ── Docs ──
echo ""
echo "--- Docs ---"
check "ARCHITECTURE.md" "docs/ARCHITECTURE.md"
check "DESIGN-DECISIONS.md" "docs/DESIGN-DECISIONS.md"
check "PLATFORMS.md" "docs/PLATFORMS.md"
check "USAGE.md" "docs/USAGE.md"

# ── Examples ──
echo ""
echo "--- Examples ---"
check "coding-refactor.md" "examples/coding-refactor.md"
check "deployment-cleanup.md" "examples/deployment-cleanup.md"
check "database-migration.md" "examples/database-migration.md"

# ── Tests ──
echo ""
echo "--- Tests ---"
check "test-scenarios.md" "tests/test-scenarios.md"
check "test-skill-structure.sh" "tests/test-skill-structure.sh"
if [ -f "$SKILL_DIR/tests/test-risk-scoring.ps1" ]; then
    green "  ✓ test-risk-scoring.ps1"
    PASS=$((PASS + 1))
else
    yellow "  ⚠ test-risk-scoring.ps1 not present"
    WARN=$((WARN + 1))
fi
if [ -f "$SKILL_DIR/tests/test-risk-scoring.sh" ]; then
    green "  ✓ test-risk-scoring.sh"
    PASS=$((PASS + 1))
else
    yellow "  ⚠ test-risk-scoring.sh not present"
    WARN=$((WARN + 1))
fi

# ── GitHub ──
echo ""
echo "--- .github ---"
check "ci.yml" ".github/workflows/ci.yml"
check "bug-report.md" ".github/ISSUE_TEMPLATE/bug-report.md"
check "feature-request.md" ".github/ISSUE_TEMPLATE/feature-request.md"
check "PULL_REQUEST_TEMPLATE.md" ".github/PULL_REQUEST_TEMPLATE.md"

# ── Cross-reference checks ──
echo ""
echo "--- Cross-references ---"
check_content "SKILL.md references fn-ci-cd" "SKILL.md" "fn-ci-cd"
check_content "SKILL.md references fn-git-aware" "SKILL.md" "fn-git-aware"
check_content "SKILL.md references fn-process-aware" "SKILL.md" "fn-process-aware"
check_content "SKILL.md references fn-language-aware" "SKILL.md" "fn-language-aware"
check_content "SKILL.md references fn-integrity-guard" "SKILL.md" "fn-integrity-guard"
check_content "behaviour.md references fn-git-aware" "behaviour.md" "fn-git-aware"
check_content "behaviour.md references fn-process-aware" "behaviour.md" "fn-process-aware"

echo ""
echo "========================================"
echo " Results: $PASS passed, $FAIL failed, $WARN warnings"
echo "========================================"

# Return exit code based on failures only
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
