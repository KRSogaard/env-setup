#!/bin/bash

# Hyprland Installation Script for Arch Linux
# This script installs Hyprland and all dependencies based on the configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Arch Linux
if ! command -v pacman &> /dev/null; then
    error "This script is designed for Arch Linux systems with pacman"
    exit 1
fi

log "Starting Hyprland installation..."

# Update system first
log "Updating system packages..."
sudo pacman -Syu --noconfirm

# Install core Hyprland packages
log "Installing Hyprland core packages..."
sudo pacman -S --needed --noconfirm \
    hyprland \
    hyprpaper \
    hypridle \
    hyprlock \
    hyprshot \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk

# Install required applications based on config
log "Installing required applications..."
sudo pacman -S --needed --noconfirm \
    waybar \
    dunst

# Install clipboard and notification tools
log "Installing clipboard and notification tools..."
sudo pacman -S --needed --noconfirm \
    wl-clipboard \
    cliphist \
    libnotify

# Install fonts and theming
log "Installing fonts and theming packages..."
sudo pacman -S --needed --noconfirm \
    ttf-font-awesome \
    noto-fonts \
    noto-fonts-emoji \
    ttf-dejavu \
    ttf-liberation

# Install wallpaper dependencies (for wallpaper rotation script)
log "Installing wallpaper management tools..."
sudo pacman -S --needed --noconfirm \
    findutils \
    coreutils

# Check if dotfiles are installed
if [[ -d "$HOME/.dotfiles" ]]; then
    log "Dotfiles directory found at ~/.dotfiles"
    
    # Check if Hyprland config exists
    if [[ -f "$HOME/.config/hypr/hyprland.conf" ]]; then
        log "Hyprland configuration already exists"
    else
        warn "Hyprland configuration not found. You may need to run your dotfiles installation."
    fi
else
    warn "Dotfiles directory not found. Make sure to install dotfiles with ./install.sh"
fi

# Create necessary directories
log "Creating necessary directories..."
mkdir -p "$HOME/.config/hypr/scripts"
mkdir -p "$HOME/Pictures/Wallpapers/Rotations/ultrawide"
mkdir -p "$HOME/Pictures/Wallpapers/Rotations/4k"
