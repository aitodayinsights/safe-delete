# Example: Code Refactor Walkthrough

## Scenario

A developer asks their agent to refactor a monolithic `auth.js` file into smaller, focused modules.

**Goal:** Split authentication logic into `auth-login.js`, `auth-signup.js`, `auth-middleware.js`

**Risk:** The deletion of `auth.js` is a side effect of the refactor — not the primary goal.

---

## Step 1: Agent Plans the Work

```
User: "Split auth.js into smaller modules — login, signup, and middleware"

Agent: Analyzing auth.js...

  auth.js (284 lines, imported by 8 files)
  ├── login function    → will go to auth-login.js
  ├── signup function   → will go to auth-signup.js
  ├── token middleware  → will go to auth-middleware.js

  Plan:
  1. ✓ Create auth-login.js    (new)
  2. ✓ Create auth-signup.js   (new)
  3. ✓ Create auth-middleware.js (new)
  4. ⚠ Delete auth.js          (⚠ will be replaced)

  [safe-delete] Deploy background watcher? [Yes / No]
  This will intercept any file deletions during the refactor.
```

---

## Step 2: Watcher Deploys

```
[Agent deploys watcher — runs in background]
[Watcher monitors filesystem operations]
[Only file deletions trigger the modal — all other operations pass through]
```

---

## Step 3: Work Proceeds

```
[Agent creates auth-login.js]
[Agent creates auth-signup.js]
[Agent creates auth-middleware.js]
[All 8 importers updated to use new module names]

Everything normal so far.
```

---

## Step 4: Deletion Intercepted

```
[Agent tries to delete auth.js → watcher intercepts]

┌──────────────────────────────────────────────────┐
│ ⚠ SAFE-DELETE: Deletion Intercepted              │
│                                                   │
│ TARGET:  D:\Projects\app\src\auth.js              │
│ TYPE:    JavaScript source file                    │
│ SIZE:    12.3 KB                                   │
│ MODIFIED: 2 hours ago                             │
│                                                   │
│ ANALYSIS:                                         │
│   Risk Score:  6 (HIGH)                           │
│   │ +2 agent-initiated                            │
│   │ +2 deleted within 24h of modification         │
│   │ +1 git-tracked with changes                   │
│   │ +1 imported by 8 other files                  │
│   Git: tracked, current, unpushed changes         │
│                                                   │
│ [1] ↺ Recycle Bin          (safest, undo any time)│
│ [2] ☐ Backup + Delete      (backup + recycle bin) │
│ [3] ✗ Permanent Delete     ⚠ irreversible         │
│ [4] ⏭ Skip                 (keep the file)        │
│ [5] 🔍 Find Alternative    (other approaches)     │
└──────────────────────────────────────────────────┘
```

---

## Step 5: User Chooses

```
User selects: [1] Recycle Bin

[safe-delete]
✓ Backup saved to ~/.opencode-trash/backups/20260526_auth_js_bak/
✓ auth.js moved to Recycle Bin
✓ 8 importers verified — all point to new modules
✓ Git: auth.js removed from tracked files
✓ Audit logged to ~/.opencode-trash/deletion-log.txt
```

---

## Alternative Outcomes

### If user chose [2] Backup + Delete

```
✓ Full backup saved to ~/.opencode-trash/backups/20260526_auth_js_bak/
  (includes auth.js + any related imports)
✓ auth.js moved to Recycle Bin
✓ Duplicate backup available in safekeeper
```

### If user chose [3] Permanent Delete

```
⚠ PERMANENT DELETE — requires 2 confirmations

Confirm 1: "This cannot be undone. Continue? [y/N]"
Confirm 2: "This file was modified 2 hours ago. Still sure? [y/N]"

[safe-delete]
⚠ Permanent auth.js deleted
✓ Backup saved to safekeeper (last resort, expires 48h)
✓ Logged to permanent-deletions.log
```

### If user chose [4] Skip

```
[safe-delete]
⏭ auth.js not deleted
Agent: I'll keep auth.js in place. Continue using it as-is.
```

### If user chose [5] Find Alternative

```
Agent suggests:
  a) Rename auth.js → auth-legacy.js (kept, not deleted)
  b) Archive auth.js to ./archived/
  c) Create auth.js as a re-export of all new modules

User chooses (a): Rename
✓ auth.js → auth-legacy.js
✓ All 8 importers updated to new modules
```

---

## State After

```
src/
├── auth-legacy.js     (renamed, not deleted)
├── auth-login.js      (new)
├── auth-signup.js     (new)
├── auth-middleware.js  (new)
├── routes/
│   └── user.js        (updated: imports auth-login)
├── middleware/
│   └── app.js         (updated: imports auth-middleware)
└── (5 other importers updated)

Recovery paths:
  - Recycle Bin: auth.js (if needed)
  - Backup: ~/.opencode-trash/backups/20260526_auth_js_bak/
  - Git: git restore src/auth.js
  - Safekeeper: ~/.opencode-safekeeper/
```

---

## Key Observations

1. **The watcher was essential** — The developer didn't know auth.js would be deleted as part of the refactor
2. **Risk score captured the danger** — Agent-initiated + recently modified + imported by 8 files = 6
3. **Options preserved agency** — The developer chose their comfort level (Recycle Bin)
4. **Alternatives gave flexibility** — Renaming instead of deleting was viable
