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
# zsh + git (shell, Oh My Zsh), tmux, jq (settings merge), python3 (zshrc migration), node (claude-hud
# status line), wl-clipboard (tmux copy on Wayland), mosh (survives VPN drops).
MISSING=()
for cmd in zsh tmux jq python3 node wl-copy curl git mosh-server; do
    command -v "$cmd" &>/dev/null || MISSING+=("$cmd")
done
if [ ${#MISSING[@]} -eq 0 ]; then
    echo "   ✅ zsh, tmux, jq, python3, node, wl-clipboard, curl, git, mosh already installed"
elif command -v pacman &>/dev/null; then
    sudo pacman -S --needed --noconfirm zsh tmux jq python nodejs wl-clipboard curl git mosh
elif command -v apt-get &>/dev/null; then
    sudo apt-get update -y
    sudo apt-get install -y zsh tmux jq python3 nodejs wl-clipboard curl git mosh
else
    echo "   ⚠️  Unknown package manager — install manually: ${MISSING[*]}"
fi

# Old distro Node (Ubuntu 22.04 ships 12) cannot run the claude-hud status line.
if command -v node &>/dev/null && [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 18 ]; then
    echo "   ⚠️  node $(node --version) is older than 18 — the claude-hud status line needs 18+ (e.g. NodeSource)"
fi

echo ""
echo "🤖 Claude Code..."
install_claude_code

deploy_all
