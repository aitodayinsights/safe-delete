# Platform Setup

## Installation Paths by Agent

| Platform | Path |
|----------|------|
| **OpenCode** | `~/.config/opencode/skills/safe-delete/` |
| **Claude Code** | `~/.claude/skills/safe-delete/` |
| **Cursor** | `.cursor/skills/safe-delete/` (project) or global |
| **VS Code / Codex** | `~/.codex/skills/safe-delete/` |
| **GitHub Copilot CLI** | `~/.config/github-copilot/skills/safe-delete/` |
| **Gemini CLI** | `~/.config/gemini/skills/safe-delete/` |
| **Any agent** | Copy to your agent's skills directory |

---

## OpenCode

### Install

```bash
# Global install
./install.sh

# Or manually
cp -r safe-delete ~/.config/opencode/skills/
```

### Configure

```yaml
# AGENTS.md
safe_delete: on
```

### Verify

```bash
opencode run "What skills are installed?"
# Should show safe-delete in the list
```

---

## Claude Code

### Install

```bash
./install.sh --claude

# Or manually
cp -r safe-delete ~/.claude/skills/
```

### Configure

```yaml
# CLAUDE.md
safe_delete: on
safekeeper_enabled: true
```

### Verify

```bash
claude code
# Then type: /safe-delete status
# Should show status panel
```

---

## Cursor

### Install

```bash
./install.sh --cursor

# Or manually
cp -r safe-delete .cursor/skills/
```

### Configure

```yaml
# .cursorrules
safe_delete: on
```

### Verify

Open Cursor Composer and ask: "What's the current safe-delete status?"

---

## VS Code / Codex

### Install

```bash
mkdir -p ~/.codex/skills/
cp -r safe-delete ~/.codex/skills/
```

### Configure

```yaml
# CODEX.md
safe_delete: on
```

---

## GitHub Copilot CLI

### Install

```bash
mkdir -p ~/.config/github-copilot/skills/
cp -r safe-delete ~/.config/github-copilot/skills/
```

### Configure

```yaml
# .github/copilot-instructions.md
safe_delete: on
```

---

## Gemini CLI

### Install

```bash
mkdir -p ~/.config/gemini/skills/
cp -r safe-delete ~/.config/gemini/skills/
```

### Configure

```yaml
# GEMINI.md
safe_delete: on
```

---

## Manual Installation (All Platforms)

```bash
# 1. Clone or copy the skill
git clone https://github.com/YOUR_USER/safe-delete.git
cd safe-delete

# 2. Copy to your agent's skills directory
# Pick one:
cp -r . ~/.config/opencode/skills/safe-delete/   # OpenCode
cp -r . ~/.claude/skills/safe-delete/             # Claude Code
cp -r . .cursor/skills/safe-delete/               # Cursor (project)

# 3. Add to your agent config
echo "safe_delete: on" >> AGENTS.md  # or CLAUDE.md / .cursorrules

# 4. Restart your agent
```

---

## Uninstall

```bash
# OpenCode
rm -rf ~/.config/opencode/skills/safe-delete/

# Claude Code
rm -rf ~/.claude/skills/safe-delete/

# Cursor
rm -rf .cursor/skills/safe-delete/

# Remove config line from your agent config file
```

---

## Storage Locations by Platform

| Data | Windows | macOS | Linux |
|------|---------|-------|-------|
| Audit log | `%USERPROFILE%\.opencode-trash\deletion-log.txt` | `~/.opencode-trash/deletion-log.txt` | `~/.opencode-trash/deletion-log.txt` |
| Backups | `%USERPROFILE%\.opencode-trash\backups\` | `~/.opencode-trash/backups/` | `~/.opencode-trash/backups/` |
| Safekeeper | `%LOCALAPPDATA%\.opencode-safekeeper\` | `~/.local/share/opencode-safekeeper/` | `~/.local/share/opencode-safekeeper/` |
| Config file | `AGENTS.md` | `CLAUDE.md` / `GEMINI.md` | `AGENTS.md` / `CLAUDE.md` |

---

## Cross-Platform Tool Equivalents

### Delete Commands

| Operation | PowerShell (Windows) | Bash (macOS/Linux) |
|-----------|---------------------|-------------------|
| Recycle Bin (file) | `[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p, 'OnlyErrorDialogs', 'SendToRecycleBin')` | `mv "$p" ~/.local/share/Trash/` |
| Recycle Bin (directory) | `[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($p, 'OnlyErrorDialogs', 'SendToRecycleBin')` | `mv "$p" ~/.local/share/Trash/` |
| Permanent delete | `Remove-Item -LiteralPath $p -Force` | `rm -rf "$p"` |
| Backup file | `Copy-Item $p $dest` | `cp "$p" "$dest"` |
| Backup directory | `Compress-Archive -Path $p -DestinationPath "$dest.zip"` | `tar czf "$dest.tar.gz" "$p"` |
| File info | `Get-Item $p` | `stat "$p"` or `ls -la "$p"` |
| Directory listing | `Get-ChildItem $p -Recurse` | `find "$p" -type f` |

### Process Checks

| Operation | PowerShell (Windows) | Bash (macOS/Linux) |
|-----------|---------------------|-------------------|
| File in use | `Test-FileInUse($p)` — see `fn-process-aware.md` | `lsof "$p"` |
| Locking process | `Get-Process \| Where-Object { $_.Modules.FileName -eq $p }` | `lsof -F pcn "$p"` |
| List open handles | `handle.exe -accepteula "$p"` | `lsof "$p"` |

### Git Checks

| Operation | PowerShell | Bash |
|-----------|-----------|------|
| File tracked? | `git ls-files --error-unmatch $p` | `git ls-files --error-unmatch "$p"` |
| Unpushed changes? | `git log --oneline --branches --not --remotes -- $p` | `git log --oneline --branches --not --remotes -- "$p"` |
| Dirty worktree? | `git diff --name-only -- $p` | `git diff --name-only -- "$p"` |
| Submodule check | `git submodule status -- $p` | `git submodule status -- "$p"` |
| Stash | `git stash push -m "message"` | `git stash push -m "message"` |

### Language Import Checks

| Language | Search Pattern |
|----------|---------------|
| Python | `grep -rl "^import $module\|^from $module" --include="*.py" .` |
| JavaScript | `grep -rl "from '.*/$module'\|require('.*/$module')" --include="*.{js,jsx}" .` |
| TypeScript | `grep -rl "from '.*/$module'\|import '.*/$module'" --include="*.{ts,tsx}" .` |
| Rust | `grep -rl "^mod $module\b" --include="mod.rs" --include="lib.rs" .` |
| Go | `grep -rl "\"$(dirname $p)\"" --include="*.go" .` |
| Java | `grep -rl "import .*\.$class;" --include="*.java" .` |
