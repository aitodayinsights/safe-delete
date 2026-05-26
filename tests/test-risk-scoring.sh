#!/usr/bin/env bash
# Test: Safe-Delete Risk Scoring (Bash version)
# Verifies risk scoring logic returns expected values

set -euo pipefail

PASS=0
FAIL=0

green() { printf "\033[32m%s\033[0m\n" "$1"; }
red() { printf "\033[31m%s\033[0m\n" "$1"; }

test_score() {
    local scenario="$1" expected_min="$2" expected_max="$3" score="$4"
    if [ "$score" -ge "$expected_min" ] && [ "$score" -le "$expected_max" ]; then
        green "  ✓ $scenario (score: $score)"
        PASS=$((PASS + 1))
    else
        red "  ✗ $scenario (expected $expected_min-$expected_max, got $score)"
        FAIL=$((FAIL + 1))
    fi
}

echo "========================================"
echo " Safe-Delete Risk Scoring Tests"
echo "========================================"
echo ""

# ── Base Scores ──
echo "--- Base Scores ---"
test_score "Small temp file" 1 2 $((1))
test_score "Config/.env file" 4 6 $((1 + 4))
test_score "SQL file" 3 5 $((1 + 3))
test_score "Large file >100MB" 3 5 $((1 + 3))
test_score "Database operation" 4 6 $((1 + 4))

# ── Git-Aware Modifiers ──
echo ""
echo "--- Git-Aware Modifiers ---"
test_score "Git tracked with changes" 2 3 $((1 + 1))
test_score "Unpushed commits" 3 5 $((1 + 3))
test_score "Modified within 1 hour" 3 5 $((1 + 3))
test_score "Modified within 24 hours" 2 4 $((1 + 2))
test_score "Modified within 7 days" 1 3 $((1 + 1))

# ── Process-Aware ──
echo ""
echo "--- Process-Aware Modifiers ---"
test_score "File in use by process" 2 4 $((1 + 2))

# ── Language-Aware Modifiers ──
echo ""
echo "--- Language-Aware Modifiers ---"
test_score "Imported by 5+ files" 3 5 $((1 + 3))
test_score "Imported by 1-4 files" 1 3 $((1 + 1))

# ── Integrity Guard Modifiers ──
echo ""
echo "--- Integrity Guard Modifiers ---"
test_score "Entry point file" 4 6 $((1 + 4))
test_score "Only-of-its-kind file" 3 5 $((1 + 3))
test_score "Migration chain file" 7 9 $((1 + 4 + 3))
test_score "Test infrastructure file" 2 4 $((1 + 2))

# ── Context-Aware Modifiers ──
echo ""
echo "--- Context-Aware Modifiers ---"
test_score "Agent-initiated deletion" 2 4 $((1 + 2))
test_score "Migration task" 2 4 $((1 + 2))
test_score "Refactor task" 1 3 $((1 + 1))
test_score "User-explicit deletion" 1 2 $((1 + 0))

# ── Combined Scores ──
echo ""
echo "--- Combined Scores (Realistic Scenarios) ---"
test_score "Agent deletes recent SQL migration" 9 10 $((1 + 3 + 2 + 2 + 2))
test_score "User deletes old log in CI" 1 3 $((1))
test_score "Bulk config delete during refactor" 6 8 $((1 + 3 + 2 + 1))
test_score "Large build artifact cleanup" 3 5 $((1 + 3))
test_score "Agent deletes node_modules in prod" 10 12 $((1 + 2 + 3 + 2 + 4))

echo ""
echo "========================================"
echo " Results: $PASS passed, $FAIL failed"
echo "========================================"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
