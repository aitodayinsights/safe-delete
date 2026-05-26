# Symlink Guard — Symlink, Hardlink & Junction Safety

## Purpose

Detect when a delete target is a symlink, hardlink, or junction point — and distinguish between deleting the link itself vs. the target it points to. This prevents inadvertently deleting shared files, system files, or files outside the project boundary.

---

## When This Activates

- Step 1 in risk scoring (checked during target analysis)
- Activates for ANY delete target
- Separates into two distinct operations:
  - **Delete the symlink** (safe — only removes the link)
  - **Delete the symlink target** (dangerous — may affect other consumers)

---

## Detection

### Windows (PowerShell)

```powershell
$item = Get-Item -LiteralPath $path -Force -EA 0
$isSymlink = $item.LinkType -eq "SymbolicLink"
$isJunction = $item.LinkType -eq "Junction"
$isHardlink = $item.LinkType -eq "HardLink"
$target = $item.Target  # resolves to target path

if ($isSymlink -or $isJunction -or $isHardlink) {
    Write-Host "Link type: $($item.LinkType)"
    Write-Host "Target: $target"
    Write-Host "Target inside project: $($target.StartsWith($projectRoot))"
}
```

### macOS / Linux (Bash)

```bash
# Symlink detection
if [ -L "$path" ]; then
    target=$(readlink -f "$path")
    echo "SYMLINK -> $target"
elif [ -f "$path" ] && [ "$(stat -c%h "$path" 2>/dev/null || stat -f%l "$path" 2>/dev/null)" -gt 1 ]; then
    echo "HARDLINK (link count > 1)"
fi

# Check if target is inside project
project_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
if [[ "$target" == "$project_root"* ]]; then
    echo "Target inside project → safe to delete symlink"
else
    echo "Target OUTSIDE project → CRITICAL"
fi
```

---

## Risk Modifiers

| Scenario | Risk Modifier | Action |
|----------|---------------|--------|
| Deleting symlink inside project | 0 (safe) | Allow — only the link is removed |
| Deleting symlink → target outside project | +5 (critical) | Warn: "Target is outside the project. Deleting the symlink is safe, but deleting the target will affect system/shared files." |
| Deleting hardlink (link count > 1) | +3 (high) | Warn: "This is a hardlink. Other hardlinks to the same inode still exist. Data is only freed when all hardlinks are deleted." |
| Deleting junction point (Windows) | +1 (low) | Warn: "This is a junction point. Only the junction is removed, not the target." |
| Appears to be symlink target (not the link itself) | +2 (medium) | Check: "Are you sure you want to delete the symlink target, not the symlink?" |

---

## Flow

```
[Target path] → [Check if symlink/hardlink/junction]
    ├── YES → [Resolve target]
    │   ├── Target inside project → Risk 0, allow delete of link
    │   ├── Target outside project → Risk +5, warn with modal
    │   └── Target is itself a symlink → recursive resolve
    │
    ├── YES (hardlink) → [Check link count]
    │   ├── Link count = 1 → Not a hardlink (ignore)
    │   └── Link count > 1 → Risk +3, warn
    │
    └── NO → Proceed with other checks
```

### Recursive Symlink Resolution

```bash
# Recursively resolve til we hit a real file
resolve_symlink() {
    local target="$1"
    while [ -L "$target" ]; do
        target=$(readlink -f "$target")
    done
    echo "$target"
}
```

---

## Modal Integration

When a symlink target is outside the project:

```
┌──────────────────────────────────────────────────────────────┐
│ ⚠ SYMLINK TARGET IS OUTSIDE PROJECT                          │
│                                                              │
│ Path:    src/link -> /usr/local/share/shared-file.txt        │
│                                                            │
│ You are about to delete the SYMLINK TARGET, not the link.    │
│ The target is OUTSIDE this project:                          │
│   /usr/local/share/shared-file.txt                          │
│                                                            │
│ This could affect other projects or system tools.            │
│                                                            │
│ [1] Delete only the SYMLINK (safe)                          │
│ [2] Delete the symlink AND its target (⚠ may affect others) │
│ [3] Skip — don't touch this                                 │
└──────────────────────────────────────────────────────────────┘
```

When deleting a hardlink:

```
┌──────────────────────────────────────────────────────────────┐
│ ⚠ HARDLINK DETECTED                                          │
│                                                              │
│ Path:     src/data.db                                        │
│ Link count: 3 other links to same inode                     │
│                                                            │
│ Deleting this removes ONE link. Data persists until all      │
│ 3 links are deleted.                                         │
│                                                            │
│ [1] Delete this link only                                    │
│ [2] Find and delete ALL hardlinks to this inode             │
│ [3] Skip — don't touch this                                 │
└──────────────────────────────────────────────────────────────┘
```

---

## Do Not

- Delete the symlink target without asking — the user may not realize it's a symlink
- Treat hardlinks as disposable — each link counts toward inode retention
- Assume junctions are safe to delete recursively — junction targets may be outside the volume
- Forget to resolve nested symlinks — one symlink can point to another
- Allow deletion of symlinks pointing to `/`, `/etc`, `/usr`, `/System`, `C:\Windows`, or other system roots
- Delete junction points targeting other drives without verification
- Let `rm -rf` follow symlinks without warning — that deletes the target
