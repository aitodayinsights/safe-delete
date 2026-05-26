#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
# Safe-Delete — Structure Validator
# ─────────────────────────────────────────────────────────
# Validates that all required files exist and cross-
# references are consistent.
# ─────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0
WARNINGS=0

check() {
    if [ -f "$SKILL_DIR/$1" ] || [ -d "$SKILL_DIR/$1" ]; then
        echo -e "  ${GREEN}✓${NC} $1"
    else
        echo -e "  ${RED}✗${NC} $1  (missing)"
        ERRORS=$((ERRORS + 1))
    fi
}

check_optional() {
    if [ -f "$SKILL_DIR/$1" ] || [ -d "$SKILL_DIR/$1" ]; then
        echo -e "  ${GREEN}✓${NC} $1"
    else
        echo -e "  ${YELLOW}⚠${NC} $1  (optional — missing)"
        WARNINGS=$((WARNINGS + 1))
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Safe-Delete — Structure Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Core files (required):"
check "SKILL.md"
check "behaviour.md"
check "commands.md"

echo ""
echo "Functions (required):"
check "functions/fn-delete-methods.md"
check "functions/fn-risk-scoring.md"
check "functions/fn-delete-modal.md"
check "functions/fn-backup.md"
check "functions/fn-audit.md"
check "functions/fn-database.md"
check "functions/fn-permanent-delete.md"
check "functions/fn-environment.md"
check "functions/fn-emergency.md"
check "functions/fn-recovery.md"
check "functions/fn-safekeeper.md"
check "functions/fn-instant-mode.md"

echo ""
echo "Production functions (v2.0 — required):"
check "functions/fn-ci-cd.md"
check "functions/fn-git-aware.md"
check "functions/fn-process-aware.md"
check "functions/fn-language-aware.md"
check "functions/fn-integrity-guard.md"

echo ""
echo "References (required):"
check "references/cheatsheet.md"

echo ""
echo "Documentation (optional but recommended):"
check_optional "README.md"
check_optional "LICENSE"
check_optional "CONTRIBUTING.md"
check_optional "CHANGELOG.md"
check_optional "version.json"
check_optional "docs/ARCHITECTURE.md"
check_optional "docs/DESIGN-DECISIONS.md"
check_optional "docs/PLATFORMS.md"
check_optional "docs/USAGE.md"

echo ""
echo "Examples (optional):"
check_optional "examples/coding-refactor.md"
check_optional "examples/deployment-cleanup.md"
check_optional "examples/database-migration.md"

echo ""
echo "Scripts (optional):"
check_optional "scripts/install.sh"
check_optional "Makefile"

echo ""
echo "Tests (optional):"
check_optional "tests/test-scenarios.md"
check_optional "tests/test-skill-structure.sh"
check_optional "tests/test-risk-scoring.ps1"
check_optional "tests/test-risk-scoring.sh"

echo ""
echo "CI (optional):"
check_optional ".github/workflows/ci.yml"
check_optional ".github/ISSUE_TEMPLATE/bug-report.md"
check_optional ".github/ISSUE_TEMPLATE/feature-request.md"
check_optional ".github/PULL_REQUEST_TEMPLATE.md"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "  ${GREEN}All checks passed!${NC}"
elif [ $ERRORS -eq 0 ]; then
    echo -e "  ${YELLOW}${WARNINGS} warnings (all optional)${NC}"
    echo -e "  ${GREEN}No errors — structure is valid${NC}"
else
    echo -e "  ${RED}${ERRORS} errors found${NC}"
    exit 1
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
