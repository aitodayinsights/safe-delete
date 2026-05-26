# Design Decisions

## Why Recycle Bin Is the Default (Not Permanent)

**Decision:** Every delete defaults to Recycle Bin. Permanent deletion is never the default.

**Rationale:** The primary failure mode of AI agents is deleting things too aggressively. Recycle Bin gives users a safety net even after they've confirmed. The cost of "file was deleted permanently" is infinitely higher than "file is in Recycle Bin, takes 2 seconds to restore."

---

## Why 5 Options in the Modal (Not 2 or 3)

**Decision:** The modal always presents 5 distinct options: Recycle Bin, Backup+Delete, Permanent, Skip, Find Alternative.

**Rationale:** Research shows that binary choices (delete/cancel) create false dilemmas. Users often want "delete but keep a copy" or "don't delete but work around it." The 5 options cover the real decision space:
- Option 1: "I'm sure, but keep safety net" → Recycle Bin
- Option 2: "I'm sure, want a backup too" → Backup+Delete
- Option 3: "I REALLY want this gone" → Permanent (guarded)
- Option 4: "Actually, leave it" → Skip
- Option 5: "Help me find another way" → Alternative

---

## Why 100MB Backup Threshold

**Decision:** Files ≤100MB auto-backup without asking. Files >100MB ask the user.

**Rationale:** 100MB is the pragmatic threshold:
- Below 100MB: Backups complete in <1 second on modern SSDs. No perceptible delay.
- Above 100MB: Backup time becomes noticeable (5 seconds to minutes). Users should consent.
- 100MB catches the vast majority of source files, configs, and small datasets.
- Large models, datasets, and databases (>100MB) are rare enough to warrant the extra question.

---

## Why the Safekeeper Is Secret

**Decision:** The safekeeper creates invisible backups in AppData that the user doesn't know about during normal flow.

**Rationale:** The user's worst case is "I emptied the Recycle Bin and now I regret it." The safekeeper provides a last-resort recovery path that survives Recycle Bin emptying. It's kept secret to avoid false confidence ("I don't need to be careful, the safekeeper has it") while still being documented for advanced recovery.

---

## Why Context-Aware Risk Modifiers Exist

**Decision:** Risk scoring adds +2 for agent-initiated deletions, +2 for migrations, +1 for refactors, etc.

**Rationale:** The original risk scoring only looked at file properties (type, size, age). But the real danger comes from context — an agent refactoring a module is much more likely to accidentally delete something important than a user explicitly cleaning temp files. These modifiers encode that contextual risk.

---

## Why Always-Bound Exists

**Decision:** Safe-delete is always active, even when "delete" isn't mentioned.

**Rationale:** The original motivation: agents working on big projects accidentally delete old files/databases as a side effect of refactoring. The user never said "delete" — they said "refactor" or "fix." Always-bound catches these hidden deletion risks.

---

## Why CI Mode Has Different Behaviour

**Decision:** In CI/headless mode, the modal is skipped and risk-based auto-defaults are used.

**Rationale:** CI pipelines have no interactive terminal. A modal that waits for input would hang indefinitely. Instead, we use safer defaults (always backup, block risk ≥8) and emit machine-parseable logs. The `SAFE_DELETE_CI=true` override acknowledges that CI pipelines are intentional about their operations.

---

## Why Git-Aware Is Separate from Risk Scoring

**Decision:** Git checks are a separate function (`fn-git-aware.md`) rather than being embedded in the risk scorer.

**Rationale:** Git checks are complex (unpushed commits, dirty worktrees, submodules) and have their own user interactions (stash suggestions, commit prompts). Mixing them into the numeric risk scorer would create a confusing hybrid. Separation of concerns keeps each layer clean.

---

## Why Language-Aware Import Analysis

**Decision:** Before deleting a source file, analyze the import graph to find all files that would break.

**Rationale:** An agent can't see the implicit web of imports the way a senior developer can. Deleting `helpers.ts` looks harmless until you realize 20 files import from it. Static import analysis makes this visible.

---

## Why Process-Aware Checks Matter

**Decision:** Before deleting a file, check if it's in use by a running process.

**Rationale:** Deleting a config file or database that a running service depends on will crash that service. Process-aware checks prevent this by detecting open handles and locking processes.

---

## Why /safe-delete off Doesn't Disable All Protection

**Decision:** When OFF, the skill still activates on explicit trigger words — it just skips proactive always-bound analysis.

**Rationale:** Users might turn safe-delete off to reduce friction during read-only tasks, but they still want protection when they explicitly say "delete this file." The OFF state is "don't watch proactively" not "don't protect at all."

---

## Why We Use Recycle Bin Over rm/Remove-Item

**Decision:** All deletions go through the OS Recycle Bin by default.

**Rationale:** `rm` and `Remove-Item -Force` are permanent and unrecoverable. Recycle Bin provides a safety net that non-technical users know how to access. The cost: Recycle Bin takes slightly more time. The benefit: files are always recoverable without special tools.

---

## Why No "Undo" Button (Recovery Is Separate)

**Decision:** There's no single "undo" button. Recovery is handled through multiple paths (Recycle Bin, backups, git, safekeeper).

**Rationale:** A single undo would need to know which recovery path to use, which is context-dependent. Instead, each recovery path is documented separately and the user/agent picks the right one.
