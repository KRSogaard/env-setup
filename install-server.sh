#!/bin/bash

# =============================================================================
# Idempotent Remote Server Setup Script (tmux + Claude Code dev profiles)
# Supports Ubuntu/Debian and Arch Linux
# Optimized for SSH access from macOS
# Can be run multiple times - only installs/configures what's missing
# =============================================================================

set -e

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

pkg_installed() {
    case "$DISTRO" in
        debian) dpkg -l "$1" 2>/dev/null | grep -q "^ii" ;;
        arch)   pacman -Qi "$1" &>/dev/null ;;
    esac
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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
        ;;
    arch)
        echo "Updating package database..."
        sudo pacman -Sy --noconfirm
        echo ""
        echo "Installing essentials..."
        pkg_install git curl wget unzip base-devel
        ;;
esac

echo ""
echo "Essentials installed"
echo ""

# -----------------------------------------------------------------------------
# Git Setup
# -----------------------------------------------------------------------------

echo "========================================="
echo "  Setting up Git"
echo "========================================="
echo ""

if [[ "$(git config --global credential.helper)" != "store" ]]; then
    git config --global credential.helper store
    echo "   - Credential helper: store"
else
    echo "   Credential helper already configured"
fi

if [[ "$(git config --global user.name)" != "Kasper Sogaard" ]]; then
    git config --global user.name "Kasper Sogaard"
    echo "   - Username: Kasper Sogaard"
else
    echo "   Username already configured"
fi

if [[ "$(git config --global user.email)" != "kasper@sogaard.us" ]]; then
    git config --global user.email "kasper@sogaard.us"
    echo "   - Email: kasper@sogaard.us"
else
    echo "   Email already configured"
fi

if [[ "$(git config --global push.autoSetupRemote)" != "true" ]]; then
    git config --global push.autoSetupRemote true
    echo "   - Auto push new branches: enabled"
else
    echo "   Auto push already configured"
fi

if [[ "$(git config --global init.defaultBranch)" != "master" ]]; then
    git config --global init.defaultBranch master
    echo "   - Default branch: master"
else
    echo "   Default branch already configured"
fi

echo ""
echo "Setting up GitHub credentials..."
if ! grep -q "github.com" ~/.git-credentials 2>/dev/null; then
    read -sp "   Enter your GitHub Personal Access Token (PAT): " GITHUB_PAT
    echo ""
    if [ -n "$GITHUB_PAT" ]; then
        echo "https://KRSogaard:${GITHUB_PAT}@github.com" >> ~/.git-credentials
        chmod 600 ~/.git-credentials
        echo "   GitHub PAT stored"
    else
        echo "   No token entered, skipping"
    fi
else
    echo "   GitHub credentials already stored"
fi

echo ""
echo "Git setup completed"
echo ""

# -----------------------------------------------------------------------------
# Dev Profiles (tmux + Claude Code work/personal)
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
