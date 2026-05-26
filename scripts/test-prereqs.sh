#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
# Safe-Delete — Prerequisite Checker
# ─────────────────────────────────────────────────────────
# Checks that the system has everything needed to run
# safe-delete tests and validation.
# ─────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check_cmd() {
    if command -v "$1" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $1 found"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗${NC} $1 not found"
        FAIL=$((FAIL + 1))
    fi
}

check_platform() {
    case "$(uname -s)" in
        Linux*)   echo "  ${GREEN}✓${NC} Platform: Linux" ;;
        Darwin*)  echo "  ${GREEN}✓${NC} Platform: macOS" ;;
        CYGWIN*|MINGW*|MSYS*) echo "  ${GREEN}✓${NC} Platform: Windows (via MSYS)" ;;
        *)        echo "  ${YELLOW}⚠${NC} Platform: $(uname -s) (untested)" ;;
    esac
    PASS=$((PASS + 1))
}

check_shell() {
    if [ -n "$BASH_VERSION" ]; then
        echo -e "  ${GREEN}✓${NC} Shell: bash $BASH_VERSION"
    else
        echo -e "  ${YELLOW}⚠${NC} Shell: not bash (may affect script compatibility)"
    fi
    PASS=$((PASS + 1))
}

check_pwsh() {
    if command -v pwsh &>/dev/null; then
        local ver
        ver=$(pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}✓${NC} PowerShell Core: $ver"
    elif command -v powershell &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} PowerShell (Windows)"
    else
        echo -e "  ${YELLOW}⚠${NC} PowerShell not found (Windows tests will skip)"
    fi
    PASS=$((PASS + 1))
}

check_git() {
    if command -v git &>/dev/null; then
        local ver
        ver=$(git --version 2>/dev/null | awk '{print $3}')
        echo -e "  ${GREEN}✓${NC} git: $ver"
    else
        echo -e "  ${RED}✗${NC} git not found (required for git-aware tests)"
        FAIL=$((FAIL + 1))
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Safe-Delete — Prerequisite Checker"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

check_platform
check_shell
echo ""
echo "Required:"
check_cmd "bash"
check_cmd "git"
check_cmd "cp"
check_cmd "rm"
check_cmd "mv"
check_cmd "find"
check_cmd "grep"
check_cmd "awk"
check_cmd "sed"

echo ""
echo "Optional:"
check_pwsh
check_cmd "markdownlint" || true
check_cmd "mdl" || true
check_cmd "shellcheck" || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}All prerequisites met! ($PASS checks passed)${NC}"
else
    echo -e "  ${RED}$FAIL prerequisite(s) missing${NC}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
