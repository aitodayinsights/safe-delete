# Cloud Sync Guard — Cloud Directory & Reversible Storage Detection

## Purpose

Detect when a delete target is inside a cloud-synced directory (OneDrive, Dropbox, iCloud, Google Drive). Deletion in a synced directory propagates to ALL devices — making it effectively irreversible without cloud trash recovery.

---

## When This Activates

- Step 1 in risk scoring (checked during target analysis)
- Activates for ANY delete target

---

## Detection by Platform

### Microsoft OneDrive

```powershell
# Consumer OneDrive
$onedrive = $env:OneDrive
if ($path -like "$onedrive*") { "ONEDRIVE_CONSUMER" }

# Business/Commercial OneDrive
$onedriveBiz = $env:OneDriveCommercial
if ($path -like "$onedriveBiz*") { "ONEDRIVE_BUSINESS" }
```

```bash
# macOS/Linux
test -n "$OneDrive" && echo "ONEDRIVE"
# Check common locations
ls -la ~/OneDrive 2>/dev/null && echo "ONEDRIVE_DETECTED"
ls -la ~/OneDrive\ -\ * 2>/dev/null && echo "ONEDRIVE_BUSINESS_DETECTED"
```

### Dropbox

```powershell
$dropbox = "$env:LOCALAPPDATA\Dropbox"
if ($path -like "*Dropbox*") {
    $dbPath = "$env:USERPROFILE\Dropbox"
    if ($path -like "$dbPath*") { "DROPBOX_DETECTED" }
}
```

```bash
ls -la ~/Dropbox 2>/dev/null && echo "DROPBOX_DETECTED"
test -f ~/.dropbox/info.json && echo "DROPBOX_DETECTED"
```

### iCloud Drive

```powershell
$icloud = "$env:USERPROFILE\iCloudDrive"
if ($path -like "$icloud*") { "ICLOUD_DETECTED" }
```

```bash
ls -la ~/Library/Mobile\ Documents/ 2>/dev/null && echo "ICLOUD_DETECTED"  # macOS
ls -la ~/iCloudDrive 2>/dev/null && echo "ICLOUD_DETECTED"  # other
```

### Google Drive

```powershell
$gdrive = "$env:USERPROFILE\Google Drive"
if ($path -like "$gdrive*") { "GOOGLE_DRIVE_DETECTED" }
```

```bash
ls -la ~/Google\ Drive 2>/dev/null && echo "GOOGLE_DRIVE_DETECTED"
ls -la ~/Library/CloudStorage/GoogleDrive-* 2>/dev/null && echo "GOOGLE_DRIVE_DETECTED"  # macOS
```

### Generic Detection

Check for common cloud drive markers:

```bash
# macOS cloud storage paths
ls -d ~/Library/Mobile\ Documents/ 2>/dev/null && echo "ICLOUD"
ls -d ~/Library/CloudStorage/ 2>/dev/null && echo "CLOUD_STORAGE"

# Common env vars
env | grep -i "icloud\|onedrive\|dropbox\|gdrive\|googledrive" 2>/dev/null
```

```powershell
# Check common env vars
Get-ChildItem Env:* | Where-Object { $_.Name -match "OneDrive|Dropbox|iCloud|GoogleDrive" } | Select-Object Name, Value
```

---

## Risk Modifiers

| Scenario | Risk Modifier | Rationale |
|----------|---------------|-----------|
| File in OneDrive | +3 | Synced to all devices + cloud. Check cloud trash. |
| File in Dropbox | +3 | Synced to all devices. Dropbox keeps 30d version history. |
| File in iCloud | +3 | Synced to all Apple devices. iCloud has 30d trash. |
| File in Google Drive | +3 | Synced to cloud. Google Drive has 30d trash. |
| File in synced dir + file is open | +5 | Sync conflict risk if file is in use |
| Large file (>100MB) in synced dir | +2 | Syncing large deletes consumes bandwidth |
| File in synced dir + user is offline | +1 | Deletion will queue, sync on reconnect |

---

## Flow

```
[Target path] → [Check cloud sync status]
    ├── IN CLOUD DIR → [Identify provider]
    │   ├── OneDrive    → Risk +3, warn about multi-device sync
    │   ├── Dropbox     → Risk +3, mention 30d version history
    │   ├── iCloud      → Risk +3, mention 30d trash recovery
    │   ├── Google Drive→ Risk +3, mention 30d trash recovery
    │   └── Unknown     → Risk +2, generic cloud warning
    │
    └── NOT IN CLOUD DIR → Skip, proceed normally
```

---

## Modal Integration

When a cloud-synced file is targeted for deletion:

```
┌──────────────────────────────────────────────────────────────┐
│ ⚠ CLOUD-SYNCED FILE: Deletion Will Sync                     │
│                                                              │
│ Path:     C:\Users\Name\OneDrive\Documents\config.json       │
│ Provider: Microsoft OneDrive                                  │
│                                                            │
│ This file is synced to OneDrive. Deleting it will:           │
│   • Remove from this computer                                │
│   • Sync deletion to all other devices                       │
│   • Send to OneDrive Recycle Bin (93-day retention)          │
│                                                            │
│ [1] Delete to Recycle Bin (recoverable via OneDrive web)    │
│ [2] Permanent delete (⚠ syncs to all devices, may be gone)  │
│ [3] Skip — don't touch this                                 │
└──────────────────────────────────────────────────────────────┘
```

---

## Cloud-Specific Recovery Notes

| Provider | Trash Retention | Recovery Method |
|----------|----------------|-----------------|
| OneDrive | 93 days (basic), 93d-30d (business) | onedrive.live.com → Recycle Bin |
| Dropbox | 30 days (basic), 180 days (professional) | dropbox.com → Deleted files |
| iCloud Drive | 30 days | iCloud.com → Settings → Restore Files |
| Google Drive | 30 days (basic), unlimited (business) | drive.google.com → Trash |

---

## Do Not

- Delete cloud-synced files permanently as default — always suggest Recycle Bin
- Forget to mention that deletion syncs — this is the key danger
- Assume cloud trash retention — check provider; some don't retain
- Proceed with permanent delete on cloud files without verifying user understands sync propagation
- Check for cloud sync when file is not in a synced directory (performance)
- Let `rm -rf` or `Remove-Item -Force` silently delete synced content
- Overlook business OneDrive — it's more common than consumer for devs
