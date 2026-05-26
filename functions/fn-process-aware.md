# Function 15: Process-Aware Deletion

## Purpose

Prevent deletion of files that are currently open by running processes, in use by the operating system, or referenced by active services. This prevents crashes, data corruption, and "file in use" errors.

---

## Detection Methods

### Windows (PowerShell)

```powershell
function Test-FileInUse {
    param([string]$Path)

    try {
        $file = [System.IO.File]::Open($Path, 'Open', 'Read', 'None')
        $file.Close()
        return $false  # Not in use
    } catch {
        return $true   # In use by another process
    }
}

function Get-LockingProcess {
    param([string]$Path)

    # Using HANDLE command (Sysinternals) if available
    $handle = Get-Command handle.exe -ErrorAction SilentlyContinue
    if ($handle) {
        $result = & handle.exe -accepteula -nobanner "$Path" 2>&1
        return $result
    }

    # Fallback: use netstat + Get-Process heuristic
    # Best effort — not guaranteed to find the process
    $processes = Get-Process | Where-Object {
        $_.Modules.FileName -eq $Path -or
        $_.MainModule.FileName -eq $Path
    }
    return $processes
}
```

### macOS / Linux (Bash)

```bash
# Check if file is in use (lsof)
file_in_use() {
    lsof "$1" >/dev/null 2>&1
    return $?
}

# Get locking process info
locking_process() {
    lsof -F pcn "$1" 2>/dev/null
}

# Check with fuser (Linux)
check_fuser() {
    fuser "$1" 2>/dev/null && echo "in use" || echo "free"
}
```

### Cross-Platform (Node.js/Python)

```python
# Python fallback for cross-platform checking
import psutil
import os

def get_locking_processes(filepath):
    """Return list of (pid, name) for processes using this file."""
    locking = []
    for proc in psutil.process_iter(['pid', 'name', 'open_files']):
        try:
            for of in proc.info['open_files'] or []:
                if of.path == os.path.abspath(filepath):
                    locking.append((proc.info['pid'], proc.info['name']))
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    return locking
```

---

## What We Check

| Check | What It Detects | Platform |
|-------|----------------|----------|
| File handle open | File is actively read/written | All |
| Process module | File is loaded as DLL/module | Windows |
| Working directory | Directory is CWD of running process | All |
| Service dependency | File is referenced by active service | All |
| Socket/bound port | Config file for running network service | All |
| Editor lock | File open in editor (VS Code, vim, etc.) | All |
| Database lock | SQLite/DB file is in use | All |
| Package manager lock | node_modules being installed/packaged | All |

---

## Risk Modifiers

| Condition | Risk Adjustment |
|-----------|----------------|
| File in use by running process | +3 (BLOCKED if risk > 6 after addition) |
| Directory is CWD of a process | +4 |
| File is a DLL/module of running app | +4 |
| SQLite database is locked | +3 |
| File open in editor | +1 (suggest save + close) |
| `node_modules` in use by npm/yarn | +2 (wait for install to finish) |
| Config file of running server | +3 |

---

## Process-Aware Modal

When a file is in use:

```
┌─────────────────────────────────────────────────────────────┐
│ ⚠ PROCESS-AWARE: File Currently In Use                       │
│                                                              │
│ Target: config/database.yml                                  │
│                                                              │
│ Locked by:                                                   │
│   • myapp.exe (PID 8421) — main process                      │
│   • nginx (PID 3912) — reading config on startup             │
│                                                              │
│ ⚠ Deleting this file will crash the above process(es).        │
│                                                              │
│ [1] Wait for process to finish, then retry  ✓ safest         │
│ [2] Stop process(es) first, then delete                      │
│ [3] Force delete (⚠ may crash services)                     │
│ [4] Skip — keep the file                   (recommended)     │
│ [5] Find Alternative                                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Safe Handling

### Option 1: Wait and Retry

```powershell
$maxRetries = 5
$retryDelay = 2  # seconds
for ($i = 0; $i -lt $maxRetries; $i++) {
    if (-not (Test-FileInUse $path)) {
        # File is free — proceed with delete
        break
    }
    Write-Warning "File in use. Retry $($i+1)/$maxRetries in ${retryDelay}s..."
    Start-Sleep -Seconds $retryDelay
}
```

### Option 2: Graceful Process Stop

```powershell
# Only if user explicitly approved
function Stop-LockingProcess {
    param([string]$Path)

    $processes = Get-LockingProcess $Path
    foreach ($p in $processes) {
        # Attempt graceful shutdown first
        $p.CloseMainWindow() | Out-Null
        if (-not $p.HasExited) {
            Start-Sleep -Seconds 3
            if (-not $p.HasExited) {
                $p.Kill()  # Force close
            }
        }
    }
}
```

---

## Do Not

- Do NOT delete files actively in use unless user explicitly chooses force delete
- Do NOT kill processes without telling the user exactly what will stop
- Do NOT assume "file not in use now" means "won't be in use later" — recheck before final delete
- Do NOT skip the process check for config files, databases, or executables
- Do NOT use force-close on system processes without triple confirmation
- Do NOT ignore editor lock files — VS Code, vim, and JetBrains all create lock files
