# Skill Integration — Leveraging Other Installed Skills

## Purpose

Safe-delete shouldn't operate in isolation. It detects other installed skills on the user's platform and leverages them to make better deletion decisions. This function is the bridge between safe-delete and the broader skill ecosystem.

---

## How It Works

```
[Detect Intent] → [Check installed skills] → [Leverage available context]
→ [Score Risk (with enriched context)] → [Proceed]
```

At session start and before every deletion, safe-delete checks what other skills are available and whether they have relevant context for the current operation.

### CodeFlow Note

[CodeFlow](https://github.com/braedonsaunders/codeflow) is a browser-based companion tool (not a CLI). It cannot be called from the terminal. Instead:
- If the project has a GitHub URL, the agent should **suggest** opening CodeFlow to visualize the architecture
- Use the phrase: "If you'd like to see how this file connects to other files, paste the repo URL into CodeFlow (https://codeflow-five.vercel.app/) for blast radius analysis."
- For local-only projects without a GitHub URL, skip the CodeFlow suggestion entirely

---

## Skills Safe-Delete Can Leverage

| Skill | What It Provides | When It Helps | Detection Method |
|-------|-----------------|---------------|-----------------|
| **Graphify** | Full project dependency graph (CLI) | Understanding how deleting a file affects import chains and hidden connections | `graphify --version` or `functions/fn-graphify-awareness.md` |
| **CodeFlow** | Browser-based interactive architecture map — blast radius, health score, dependency graph | When project has a GitHub URL and graphify is not installed | No CLI — check for GitHub URL, suggest opening [codeflow-five.vercel.app](https://codeflow-five.vercel.app/) |
| **Claude Memory Kit** | Cached file relationship knowledge from past sessions | If the agent has previously analyzed this file's role in the project | Existence of `MEMORY.md` or `~/.claude-memory/` |
| **fn-language-aware** | Static import graph (Python/JS/TS/Rust/Go/Java) | Always available — built into safe-delete | Always available (function reference) |
| **fn-git-aware** | Git status, unpushed commits, branch protection | Checking if file changes are safe to delete | Always available (function reference) |
| **fn-process-aware** | File-in-use detection | Checking if file is loaded by a running process | Always available (function reference) |
| **fn-integrity-guard** | Entry point, only-of-kind, migration chain checks | Structural risk assessment | Always available (function reference) |

---

## Detection Flow

```
[0] Check for graphify
    ├── Installed → Query dependent files via graphify query
    └── Not installed → Check for GitHub URL
        ├── Has GitHub URL → Suggest CodeFlow (browser-based blast radius analysis)
        └── No GitHub URL → Fall back to fn-language-aware (static import analysis)

[0.5] Check for CodeFlow accessibility
    ├── Project has GitHub URL → Can suggest opening https://codeflow-five.vercel.app/
    └── Local only → Skip CodeFlow suggestion

[1] Check for claude-memory-kit
    ├── Available → Read cached knowledge about this file or project area
    └── Not available → Skip

[2] Run fn-language-aware (always available)
    → Static import graph for the target file

[3] Run fn-git-aware (always available)
    → Git status, unpushed changes

[4] Run fn-process-aware (always available)
    → File-in-use status

[5] Run fn-integrity-guard (always available)
    → Entry point, migration chain, only-of-kind checks

[6] Merge all findings into risk score
    → Risk score enriched with graphify + memory + all guard data
    → Impact summary includes cross-skill findings
```

---

## Claude Memory Kit Integration

If the [claude-memory-kit](https://github.com/awrshift/claude-memory-kit) is installed, safe-delete can leverage its persistent memory:

### What It Can Provide

- **File importance** — if a file was discussed as critical in a past session, that knowledge persists
- **Project structure** — cached understanding of how modules relate
- **Past deletion context** — if this file was in a deletion discussion before, the memory kit has the context
- **User preferences** — if the user has expressed opinions about certain files or directories

### Detection

```bash
# Check if claude-memory-kit is installed
test -f MEMORY.md && echo "MEMORY_KIT_DETECTED" || echo "NO_MEMORY_KIT"
test -d ~/.claude-memory && echo "MEMORY_KIT_DETECTED" || echo "NO_MEMORY_KIT"
```

```powershell
# PowerShell
$hasMem = (Test-Path "MEMORY.md") -or (Test-Path "$env:USERPROFILE\.claude-memory")
if ($hasMem) { "MEMORY_KIT_DETECTED" } else { "NO_MEMORY_KIT" }
```

### Usage

When memory kit is detected:
1. Read relevant entries about the target file or project area
2. Extract any cached importance indicators
3. Incorporate into risk score (e.g., `+1` if memory kit has notes marking it as critical)
4. Include memory kit findings in the "What breaks?" impact summary

```
[Skill: claude-memory-kit]
  File: src/core/auth.js
  Cached context: "Part of the authentication rewrite (session 2026-05-25).
                   Marked as CRITICAL by user."
  → Risk modifier: +1 (user-flagged critical)
```

---

## Graphify Integration

When graphify is installed and has a cached graph, safe-delete can run targeted queries:

```bash
# Query what depends on the target file
graphify query "What files depend on $TARGET?" --graph graphify-out/graph.json
```

```
[Skill: graphify]
  File: src/utils/helpers.ts
  Graph analysis:
    - Direct importers: 12 files
    - Transitive dependents: 47 files
    - God node? Yes (top 5% connected nodes)
  → Risk modifier: +2 (transitive impact > 20 files)
  → "What breaks?": 12 direct import errors, 47 cascade failures
```

If graphify is not installed, see `fn-graphify-awareness.md` for the install suggestion flow.

---

## Adding New Skills

To add a new skill to this integration system:

1. Define a **detection method** (file existence, command check, config entry)
2. Define **what context** the skill provides for deletion decisions
3. Define **how that context modifies** risk score or impact summary
4. Add detection to the flow above

### Registration Pattern

```markdown
| Skill Name | What It Provides | Detection | Risk Modifier |
|------------|-----------------|-----------|---------------|
| `your-skill` | Description | `your-skill --version` | +1 for critical context |
```

---

## Intelligence Heuristics

To avoid "too much asking":

1. **Session cache** — Once a skill is detected or declined, remember the result for the session
2. **Tiered activation** — Graphify activation only at risk ≥ 4; memory kit always checked (free)
3. **Silent fallback** — If a skill is not installed, silently use the next available option
4. **Batched queries** — If multiple deletions are pending, query once for all targets
5. **Context window awareness** — If the agent already has the relevant structure in context, don't query again

### Example: Smart Batching

```
User: "Clean up the dead code in src/legacy/"

[Agent detects 8 files to delete]
[Agent checks skills once]
  → graphify: cached graph available (session)
  → memory kit: no entries for these files
  → fn-language-aware: 3 of 8 files have importers

[Single graphify query for all 8 targets]
  → 3 files are safe (no dependents)
  → 2 files have direct importers (show in modal)
  → 3 files have no dependents

[Present curated modal with findings for all 8]
→ User approves grouped deletion
→ One audit entry for the batch
```

---

## Do Not

- Ask to install a skill more than once per session — honor the user's choice
- Block the delete because a skill isn't available — always have a fallback
- Make the user repeat themselves — cache skill detection results
- Query skills that the user explicitly declined
- Add friction for low-risk operations (risk 1-3) — skip external skill checks
- Present raw skill output to the user — synthesize findings into the impact summary
- Rely on any single skill as the sole check — always have independent verification
- Let skill detection slow down the delete — set timeouts (5s per check, 15s total)
