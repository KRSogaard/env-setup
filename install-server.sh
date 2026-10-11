#!/bin/bash

# =============================================================================
# Idempotent Remote Server Setup Script (tmux + Claude Code dev profiles)
# Supports Ubuntu/Debian and Arch Linux
# Optimized for SSH access from macOS
# Can be run multiple times - only installs/configures what's missing
# =============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

echo "========================================="
echo "  Remote Server Setup Script"
echo "========================================="
echo ""

# -----------------------------------------------------------------------------
# Distro Detection & Package Helpers
# -----------------------------------------------------------------------------

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian|pop|linuxmint) echo "debian" ;;
            arch|manjaro|endeavouros)    echo "arch" ;;
            *)                           echo "unknown" ;;
        esac
    elif command -v apt &>/dev/null; then
        echo "debian"
    elif command -v pacman &>/dev/null; then
        echo "arch"
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)

if [ "$DISTRO" = "unknown" ]; then
    echo "Unsupported distro. This script supports Ubuntu/Debian and Arch Linux."
    exit 1
fi

echo "Detected distro: $DISTRO"
echo ""

pkg_install() {
    case "$DISTRO" in
        debian)
            sudo apt-get install -y "$@"
            ;;
        arch)
            sudo pacman -S --needed --noconfirm "$@"
            ;;
    esac
}

# -----------------------------------------------------------------------------
# System Update & Essentials
# -----------------------------------------------------------------------------

echo "========================================="
echo "  System Update & Essentials"
echo "========================================="
echo ""

case "$DISTRO" in
    debian)
        echo "Updating package lists..."
        sudo apt-get update -y
        echo ""
        echo "Installing essentials..."
        pkg_install git curl wget unzip build-essential
        # gh is in Ubuntu 22.04+ / Debian 12+; older releases need GitHub's apt repo.
        pkg_install gh || echo "   ⚠️  gh not available from apt — GitHub auth will be skipped"
        ;;
    arch)
        # Full upgrade: -Sy followed by an install is a partial upgrade,
        # which Arch does not support.
        echo "Updating system..."
        sudo pacman -Syu --noconfirm
        echo ""
        echo "Installing essentials..."
        pkg_install git curl wget unzip base-devel github-cli
        ;;
esac

echo ""
echo "Essentials installed"
echo ""

# -----------------------------------------------------------------------------
# Git Setup
# -----------------------------------------------------------------------------

setup_git
echo "Git setup completed"
echo ""

# -----------------------------------------------------------------------------
# SSH
# -----------------------------------------------------------------------------

harden_sshd
echo ""

# -----------------------------------------------------------------------------
# Dev Profiles (zsh, tmux, Claude Code work/personal, secrets)
# -----------------------------------------------------------------------------

bash "$SCRIPT_DIR/dev/install-linux.sh"

# -----------------------------------------------------------------------------
# Folder Structure
# -----------------------------------------------------------------------------

echo "========================================="
echo "  Creating folder structure"
echo "========================================="
echo ""

if [ ! -d ~/workspaces ]; then
    mkdir -p ~/workspaces
    echo "   Created ~/workspaces"
else
    echo "   ~/workspaces already exists"
fi

echo ""

# -----------------------------------------------------------------------------
# Done!
# -----------------------------------------------------------------------------

echo "========================================="
echo "  Remote server setup finished!"
echo "========================================="
echo ""
echo "This script is idempotent - run it again anytime to ensure everything is set up!"
echo ""
echo "Usage:"
echo "  dev-work          Attach to the work tmux session (work Claude account)"
echo "  dev-personal      Attach to the personal tmux session (personal account)"
echo "  dev-status        Show which Claude account is actually logged in"
echo ""
echo "Clipboard: Yanking in tmux copies to your Mac clipboard via OSC 52."
echo "Make sure your terminal (Ghostty/WezTerm) supports OSC 52 clipboard."
echo ""
