#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
# Safe-Delete — Cross-Platform Installer
# ─────────────────────────────────────────────────────────
# Installs safe-delete skill for OpenCode, Claude Code,
# Cursor, Codex, Copilot CLI, Gemini CLI, or any agent.
#
# Usage:
#   ./install.sh                   # Auto-detect + install global
#   ./install.sh --local           # Install in ./.opencode/skills/
#   ./install.sh --project         # Install in ./.opencode/
#   ./install.sh --help            # Show help
# ─────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_NAME="safe-delete"

show_help() {
    cat <<EOF
Safe-Delete Installer v2.0

Usage:
  ./install.sh                   Auto-detect + install globally
  ./install.sh --local           Install in ./.opencode/skills/
  ./install.sh --project         Install in ./.opencode/
  ./install.sh --claude          Install for Claude Code
  ./install.sh --cursor          Install for Cursor
  ./install.sh --help            Show this help

Installs to:
  Global:  ~/.config/opencode/skills/$SKILL_NAME/
  Local:   ./.opencode/skills/$SKILL_NAME/
  Project: ./.opencode/
  Claude:  ~/.claude/skills/$SKILL_NAME/
  Cursor:  ./.cursor/skills/$SKILL_NAME/
EOF
    exit 0
}

detect_agent() {
    if command -v opencode &>/dev/null; then
        echo "opencode"
    elif command -v claude &>/dev/null; then
        echo "claude-code"
    elif [ -d ".cursor" ]; then
        echo "cursor"
    elif [ -d ".github" ] && command -v gh &>/dev/null; then
        echo "copilot"
    elif command -v code &>/dev/null; then
        echo "codex"
    else
        echo "unknown"
    fi
}

install_to() {
    local dest="$1"
    mkdir -p "$dest"

    log_info "Installing to: $dest"

    cp -r "$SRC_DIR/SKILL.md" "$dest/" 2>/dev/null || true
    cp -r "$SRC_DIR/behaviour.md" "$dest/" 2>/dev/null || true
    cp -r "$SRC_DIR/commands.md" "$dest/" 2>/dev/null || true
    [ -d "$SRC_DIR/functions" ] && cp -r "$SRC_DIR/functions" "$dest/"
    [ -d "$SRC_DIR/references" ] && cp -r "$SRC_DIR/references" "$dest/"
    [ -d "$SRC_DIR/scripts" ] && cp -r "$SRC_DIR/scripts" "$dest/"
    [ -d "$SRC_DIR/docs" ] && cp -r "$SRC_DIR/docs" "$dest/"
    [ -d "$SRC_DIR/examples" ] && cp -r "$SRC_DIR/examples" "$dest/"
    [ -d "$SRC_DIR/tests" ] && cp -r "$SRC_DIR/tests" "$dest/"

    log_ok "Installed to $dest"
    log_info "Add to your agent config:"
    log_info "  safe_delete: on"
}

case "${1:-}" in
    --help|-h)
        show_help
        ;;
    --local)
        install_to "$(pwd)/.opencode/skills/$SKILL_NAME"
        ;;
    --project)
        install_to "$(pwd)/.opencode/"
        ;;
    --claude)
        install_to "$HOME/.claude/skills/$SKILL_NAME"
        ;;
    --cursor)
        install_to "$(pwd)/.cursor/skills/$SKILL_NAME"
        ;;
    "")
        AGENT=$(detect_agent)
        log_info "Detected agent: $AGENT"

        case "$AGENT" in
            opencode)
                install_to "$HOME/.config/opencode/skills/$SKILL_NAME"
                ;;
            claude-code)
                install_to "$HOME/.claude/skills/$SKILL_NAME"
                ;;
            cursor)
                install_to "$(pwd)/.cursor/skills/$SKILL_NAME"
                ;;
            copilot)
                install_to "$HOME/.config/github-copilot/skills/$SKILL_NAME"
                ;;
            codex)
                install_to "$HOME/.codex/skills/$SKILL_NAME"
                ;;
            *)
                log_warn "Could not detect agent. Installing globally..."
                install_to "$HOME/.config/opencode/skills/$SKILL_NAME"
                ;;
        esac
        ;;
    *)
        log_error "Unknown option: $1"
        show_help
        ;;
esac

log_ok "Safe-Delete installation complete!"
log_info "Restart your agent to load the skill."
