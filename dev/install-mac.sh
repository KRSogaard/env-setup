#!/bin/bash

# =============================================================================
# Idempotent dev-profile setup for macOS:
# work / personal Claude Code accounts in tmux. Run it again to update.
# =============================================================================

set -e
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

echo "========================================="
echo "🤖 Dev profiles setup (macOS)"
echo "========================================="
echo ""

if ! command -v brew &>/dev/null; then
    echo "❌ Homebrew is required — run ../install-mac.sh or install it from https://brew.sh"
    exit 1
fi

echo "📦 Installing packages..."
# tmux, jq (settings merge), node (claude-hud status line). python3 ships
# with the Xcode Command Line Tools.
for formula in tmux jq node mosh zsh-autosuggestions zsh-syntax-highlighting; do
    if brew list "$formula" &>/dev/null; then
        echo "   ✅ $formula already installed"
    else
        brew install "$formula"
    fi
done

echo ""
echo "🤖 Claude Code..."
install_claude_code

deploy_all
