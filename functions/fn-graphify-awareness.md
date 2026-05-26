# Graphify Awareness — Dependency Graph for Safe Deletion

## Purpose

Before any deletion, check if [graphify](https://github.com/safishamsi/graphify) — a knowledge graph tool for codebases — is available. If it is, use its dependency graph to understand how deleting a file affects the entire project. If not, offer to install it or fall back to static import analysis.

Graphify turns any folder into a queryable knowledge graph (`graphify-out/graph.json` + `graph.html` + `GRAPH_REPORT.md`). It handles 31 programming languages, docs, PDFs, images, and more — all processed locally for code, with optional LLM extraction for docs/media.

---

## When This Activates

- Step 0f in the workflow: after CI mode check (0e), before risk scoring (1)
- Only when the target is a source code file, config, or data file that could have dependencies
- Only active when safe-delete is ON or WATCHER mode

---

## Detection

### Check if graphify is installed

```bash
# Cross-platform check
graphify --version 2>/dev/null && echo "INSTALLED" || echo "NOT_INSTALLED"
```

```powershell
# PowerShell
$g = Get-Command graphify -EA 0; if ($g) { "INSTALLED" } else { "NOT_INSTALLED" }
```

### Check if graph is cached

```bash
# Check for existing graph
test -f graphify-out/graph.json && echo "CACHED" || echo "NOT_CACHED"

# Check freshness (is it older than source changes?)
find . -newer graphify-out/graph.json -name "*.py" -o -name "*.js" -o -name "*.ts" 2>/dev/null
```

---

## Flow

### If graphify IS installed + graph IS cached + fresh

1. Query the graph for deletion impact:
   ```
   graphify query "What depends on $TARGET_FILE?"
   graphify query "If $TARGET_FILE is deleted, what breaks?"
   ```
2. Present impact summary alongside the delete modal
3. No credit cost — cached graph queries are free

### If graphify IS installed + graph IS NOT cached (or stale)

1. Estimate cost based on project size (see below)
2. Present to user:

```
┌──────────────────────────────────────────────────────────────┐
│ ⚠ Dependency Graph: Not Built                                │
│                                                              │
│ This project has ~{file_count} files across {directory_count} │
│ directories. Building a dependency graph for safe-delete      │
│ impact analysis would use approximately:                     │
│                                                              │
│   ~{estimated_credits} credits (one-time)                    │
│   ╰─ Based on project size: {size_tier}                      │
│                                                              │
│ The graph is cached after build — future queries are free.   │
│                                                              │
│ [1] Build graph now (recommended)                            │
│ [2] Skip — use static import analysis instead                │
│ [3] Schedule for later (remind me next time)                 │
│ [4] Find Alternative                                         │
└──────────────────────────────────────────────────────────────┘
```

3. If [1] Build: Run `graphify extract . --no-viz` (API-based extraction) or `graphify query "..."` 
4. If [2] Skip: Fall back to `fn-language-aware.md` for static import analysis
5. If [3] Schedule: Flag for next session, skip for now

### If graphify is NOT installed

```
┌──────────────────────────────────────────────────────────────┐
│ ⚠ Dependency Graph: Not Available                            │
│                                                              │
│ Graphify can show exactly how deleting this file affects      │
│ every other file in the project — import chains, call flows,  │
│ and hidden dependencies.                                      │
│                                                              │
│ Install it to make safe-delete structure-aware?               │
│   (github.com/safishamsi/graphify — 53.8k★, MIT license)     │
│                                                              │
│ [1] Download & install globally (uv/pipx) — ~30 seconds       │
│ [2] Skip — use static import analysis                         │
│ [3] I'll handle it — let me write my own suggestion           │
└──────────────────────────────────────────────────────────────┘
```

Option [1]: Install graphify
```bash
# Auto-detect best install method
if command -v uv &>/dev/null; then
    uv tool install graphifyy
elif command -v pipx &>/dev/null; then
    pipx install graphifyy
else
    pip install graphifyy
fi
graphify install  # Register with current agent platform
```

Option [2]: Fall back to `fn-language-aware.md`
- Static import analysis (Python/JS/TS/Rust/Go/Java)
- No graph visualization, no surprise connections detection
- Faster but less thorough

Option [3]: User writes their own suggestion
- Free text field for the user to describe their preferred approach
- Agent adapts based on user input

---

## Credit Estimation (Simple Heuristic)

| Project Size | File Count | Estimated Credits | Auto-Proceed? |
|-------------|-----------|-------------------|---------------|
| **Tiny** | < 50 files | ~50-100 | ✅ Auto (no question) |
| **Small** | 50-200 files | ~100-250 | ✅ Auto |
| **Medium** | 200-1,000 files | ~250-800 | ❌ Ask user |
| **Large** | 1,000-5,000 files | ~800-3,000 | ❌ Ask user |
| **Very Large** | 5,000-20,000 files | ~3,000-10,000 | ❌ Ask user + warn |
| **Monolith** | 20,000+ files | ~10,000+ | ❌ Block — requires explicit opt-in |

```powershell
# Estimation logic (simplified)
$fileCount = (Get-ChildItem -Recurse -File -Include *.py,*.js,*.ts,*.go,*.rs,*.java,*.rb,*.php | Measure-Object).Count
$dirCount = (Get-ChildItem -Directory -Recurse | Measure-Object).Count

if ($fileCount -lt 50)  { $tier = "tiny"; $credits = 75; $auto = $true }
elseif ($fileCount -lt 200)   { $tier = "small"; $credits = 175; $auto = $true }
elseif ($fileCount -lt 1000)  { $tier = "medium"; $credits = 500; $auto = $false }
elseif ($fileCount -lt 5000)  { $tier = "large"; $credits = 1500; $auto = $false }
elseif ($fileCount -lt 20000) { $tier = "very_large"; $credits = 6000; $auto = $false }
else                          { $tier = "monolith"; $credits = 15000; $auto = $false; $requiresOptIn = $true }

# Adjust for project complexity factor
# 0.5x for simple projects (mostly flat, few imports)
# 1.0x for normal projects
# 1.5x for complex projects (deep nesting, many interdependencies)
# 2.0x for monorepos with multiple sub-projects
$complexityFactor = 1.0
$credits = [Math]::Round($credits * $complexityFactor)
```

### Bash equivalent

```bash
# Estimation logic (Bash)
file_count=$(find . \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.go' -o -name '*.rs' -o -name '*.java' \) -type f | wc -l)

if [ "$file_count" -lt 50 ]; then
  tier="tiny"; credits=75; auto_proceed=true
elif [ "$file_count" -lt 200 ]; then
  tier="small"; credits=175; auto_proceed=true
elif [ "$file_count" -lt 1000 ]; then
  tier="medium"; credits=500; auto_proceed=false
elif [ "$file_count" -lt 5000 ]; then
  tier="large"; credits=1500; auto_proceed=false
elif [ "$file_count" -lt 20000 ]; then
  tier="very_large"; credits=6000; auto_proceed=false
else
  tier="monolith"; credits=15000; auto_proceed=false; requires_opt_in=true
fi
```

---

## Credit Optimization

To minimize credit usage:

1. **Use `--no-viz`** — Skip HTML visualization (only build JSON + report)
2. **Use `--mode fast`** — Simpler extraction, fewer API calls (when available)
3. **Cache reuse** — Once built, query the cached graph for all future deletions in this session
4. **Incremental updates** — `graphify extract . --update` only re-extracts changed files
5. **File-type filtering** — Only analyze relevant file types for the current deletion target

```bash
# Optimal: fast extraction, no viz, cached for session
graphify extract . --no-viz --mode fast
```

---

## Structure Knowledge Cache

The agent maintains a session-level cache of project structure knowledge:

| Source | Cached? | When Used | Credit Cost |
|--------|---------|-----------|-------------|
| Graphify (`graphify-out/graph.json`) | ✅ Full graph | Every delete in session | Free (cached) |
| Agent's own plan analysis | ✅ Partial | During current task | Free |
| `claude-memory-kit` | ✅ Per-session | If installed (see `fn-skill-integration.md`) | Free |
| Static import analysis | ❌ Re-runs per file | Fallback when no graph | Free |

If the agent has already analyzed the project structure (either via graphify, plan analysis, or memory kit), it reuses that knowledge rather than re-building.

---

## Companion Tool: CodeFlow

If graphify is not installed and the project has a GitHub URL, consider suggesting [CodeFlow](https://github.com/braedonsaunders/codeflow) — a browser-based architecture map that provides:

- **Blast radius analysis** — select any file, see exactly what breaks if deleted
- **Interactive dependency graph** — visualize how all files connect
- **Health score** — dead code %, circular dependencies, coupling metrics
- **PR impact analysis** — paste a PR URL to see affected files

URL: `https://codeflow-five.vercel.app/` — paste any GitHub URL, no install required.

For local files: CodeFlow supports drag-and-drop or "Open Folder" — all processing happens in-browser.

---

## Do Not

- Ask to install graphify more than once per session — if user said no, use static analysis for the rest of the session
- Build a full graph for a simple delete (one temp file) — only activate when risk ≥ 4 or the file has dependencies
- Override the user's "skip" choice — respect it and fall back gracefully
- Estimate credits without showing the basis (file count, complexity, tier)
- Auto-proceed for medium+ projects — always get consent for non-trivial credit usage
- Rebuild the graph if it's already cached and fresh — reuse aggressively
- Crash if graphify isn't installed — the system works without it
- Block the delete waiting for graphify — set short timeout (15s), fall back if it takes longer
