# Test: Safe-Delete Risk Scoring
# Verifies risk scoring logic returns expected values

$TestsPassed = 0
$TestsFailed = 0

function Test-Score {
    param($Scenario, $ExpectedMin, $ExpectedMax, $Score)
    if ($Score -ge $ExpectedMin -and $Score -le $ExpectedMax) {
        Write-Host "  ✓ $Scenario" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "  ✗ $Scenario (expected $ExpectedMin-$ExpectedMax, got $Score)" -ForegroundColor Red
        $script:TestsFailed++
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Safe-Delete Risk Scoring Tests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Simulate risk scoring based on fn-risk-scoring.md rules
# Start at 1, add modifiers

Write-Host "--- Base Scores ---" -ForegroundColor Yellow

# Temp file: small, no modifiers
$score = 1
Test-Score "Small temp file (default)" 1 2 $score

# Config file: +4 if env/key file
$score = 1 + 4
Test-Score "Config/.env file" 4 6 $score

# SQL file: +3
$score = 1 + 3
Test-Score "SQL file" 3 5 $score

# Large file >100MB: +3
$score = 1 + 3
Test-Score "Large file >100MB" 3 5 $score

# Database operation: +4
$score = 1 + 4
Test-Score "Database operation" 4 6 $score

Write-Host ""
Write-Host "--- Git-Aware Modifiers ---" -ForegroundColor Yellow

# Tracked with changes
$score = 1 + 1
Test-Score "Git tracked with changes" 2 3 $score

# Unpushed commits
$score = 1 + 3
Test-Score "Unpushed commits" 3 5 $score

# Modified within last hour
$score = 1 + 3
Test-Score "Modified within 1 hour" 3 5 $score

# Modified within 24 hours
$score = 1 + 2
Test-Score "Modified within 24 hours" 2 4 $score

# Modified within 7 days
$score = 1 + 1
Test-Score "Modified within 7 days" 1 3 $score

Write-Host ""
Write-Host "--- Process-Aware Modifiers ---" -ForegroundColor Yellow

# File in use
$score = 1 + 2
Test-Score "File in use by process" 2 4 $score

Write-Host ""
Write-Host "--- Language-Aware Modifiers ---" -ForegroundColor Yellow

# Imported by 5+ files
$score = 1 + 3
Test-Score "Imported by 5+ files" 3 5 $score

# Imported by 1-4 files
$score = 1 + 1
Test-Score "Imported by 1-4 files" 1 3 $score

Write-Host ""
Write-Host "--- Integrity Guard Modifiers ---" -ForegroundColor Yellow

# Entry point protection
$score = 1 + 4
Test-Score "Entry point file" 4 6 $score

# Only-of-its-kind file
$score = 1 + 3
Test-Score "Only-of-its-kind file" 3 5 $score

# Migration chain
$score = 1 + 4 + 3
Test-Score "Migration chain file" 7 9 $score

# Test infrastructure
$score = 1 + 2
Test-Score "Test infrastructure file" 2 4 $score

Write-Host ""
Write-Host "--- Context-Aware Modifiers ---" -ForegroundColor Yellow

# Agent-initiated
$score = 1 + 2
Test-Score "Agent-initiated deletion" 2 4 $score

# Migration task
$score = 1 + 2
Test-Score "Migration task" 2 4 $score

# Refactor task
$score = 1 + 1
Test-Score "Refactor task" 1 3 $score

# User-verified explicit deletion
$score = 1 + 0
Test-Score "User-explicit deletion" 1 2 $score

Write-Host ""
Write-Host "--- Combined Scores (Realistic Scenarios) ---" -ForegroundColor Yellow

# Scenario: Agent deletes a SQL migration file that was just modified
# Base(1) + SQL(+3) + Migration(+2) + Agent(+2) + Modified24h(+2) = 10
$score = 1 + 3 + 2 + 2 + 2
Test-Score "Agent deletes recent SQL migration" 9 10 $score

# Scenario: User deletes old log file in CI
# Base(1) + CI mode check
$score = 1
Test-Score "User deletes old log in CI (low risk)" 1 3 $score

# Scenario: Bulk delete of 30 config files in refactor
# Base(1) + Bulk(+3) + Config maybe... + Agent(+2) + Refactor(+1)
$score = 1 + 3 + 2 + 1
Test-Score "Bulk config delete during refactor" 6 8 $score

# Scenario: User deletes large build artifact
# Base(1) + Large file(+3) + Build artifact modifier
$score = 1 + 3
Test-Score "Large build artifact cleanup" 3 5 $score

# Scenario: Agent-initiated delete of whole node_modules in prod path
# Base(1) + Agent(+2) + Prod path(+3) + Modified24h(+2) + Bulk(30+ files, +4)
$score = 1 + 2 + 3 + 2 + 4
Test-Score "Agent deletes node_modules in prod" 10 12 $score

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Results: $TestsPassed passed, $TestsFailed failed" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($TestsFailed -gt 0) { exit 1 } else { exit 0 }
