#!/bin/bash

# =============================================================================
# Idempotent dev-profile setup for Linux (Arch or Debian/Ubuntu):
# work / personal Claude Code accounts in tmux. Run it again to update.
# =============================================================================

set -e
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

echo "========================================="
echo "🤖 Dev profiles setup (Linux)"
echo "========================================="
echo ""

echo "📦 Installing packages..."
# tmux, jq (settings merge), python3 (zshrc migration), node (claude-hud
# status line), wl-clipboard (tmux copy on Wayland).
MISSING=()
for cmd in tmux jq python3 node wl-copy curl; do
    command -v "$cmd" &>/dev/null || MISSING+=("$cmd")
done
if [ ${#MISSING[@]} -eq 0 ]; then
    echo "   ✅ tmux, jq, python3, node, wl-clipboard, curl already installed"
elif command -v pacman &>/dev/null; then
    sudo pacman -S --needed --noconfirm tmux jq python nodejs wl-clipboard curl
elif command -v apt-get &>/dev/null; then
    sudo apt-get update -y
    sudo apt-get install -y tmux jq python3 nodejs wl-clipboard curl
else
    echo "   ⚠️  Unknown package manager — install manually: ${MISSING[*]}"
fi

echo ""
echo "🤖 Claude Code..."
install_claude_code

deploy_all
