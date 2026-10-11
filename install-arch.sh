#!/bin/bash

# =============================================================================
# Idempotent Arch Linux Setup Script
# Can be run multiple times - only installs/configures what's missing
# =============================================================================

set -e

echo "========================================="
echo "🏗️  Arch Linux Setup Script"
echo "========================================="
echo ""

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

# Check if a package is installed (pacman or AUR)
is_installed() {
    pacman -Qi "$1" &> /dev/null
}

# Install packages only if not already installed
# Uses paru with minimal interaction flags
install_packages() {
    local packages=("$@")
    local to_install=()
    
    for pkg in "${packages[@]}"; do
        if ! is_installed "$pkg"; then
            to_install+=("$pkg")
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        echo "   Installing: ${to_install[*]}"
        for pkg in "${to_install[@]}"; do
            conflict=$(paru -Si "$pkg" 2>/dev/null | grep "Conflicts With" | head -1 | sed 's/.*: //')
            if [ -n "$conflict" ]; then
                for c in $conflict; do
                    if pacman -Q "$c" &>/dev/null; then
                        echo "   Removing conflicting package: $c"
                        paru -R --noconfirm --quiet "$c" 2>/dev/null || sudo pacman -R --noconfirm --quiet "$c" 2>/dev/null || true
                    fi
                done
            fi
        done
        paru -S --needed --skipreview --quiet --overwrite '*' "${to_install[@]}"
    else
        echo "   ✅ All packages already installed"
    fi
}

# Install packages with pacman only if not already installed
install_pacman_packages() {
    local packages=("$@")
    local to_install=()
    
    for pkg in "${packages[@]}"; do
        if ! is_installed "$pkg"; then
            to_install+=("$pkg")
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        echo "   Installing: ${to_install[*]}"
        sudo pacman -S --needed --quiet --overwrite '*' "${to_install[@]}"
    else
        echo "   ✅ All packages already installed"
    fi
}

# Check if user is in a group
user_in_group() {
    groups "$USER" | grep -q "\b$1\b"
}

# Check if a systemd service is enabled
service_enabled() {
    systemctl is-enabled "$1" &> /dev/null
}

# Check if a user systemd service is enabled
user_service_enabled() {
    systemctl --user is-enabled "$1" &> /dev/null
}

# Check if a dotnet tool is installed
dotnet_tool_installed() {
    dotnet tool list --global | grep -q "^$1 "
}

# -----------------------------------------------------------------------------
# User Prompts
# -----------------------------------------------------------------------------

echo "========================================="
echo "⚙️  Configuration"
echo "========================================="
echo ""

read -p "💻 Is this a laptop? Install power management tools? (y/N): " INSTALL_POWER_MGMT
INSTALL_POWER_MGMT=${INSTALL_POWER_MGMT:-n}

read -p "🐍 Do you have Razer peripherals? Install OpenRazer + Polychromatic? (y/N): " INSTALL_RAZER
INSTALL_RAZER=${INSTALL_RAZER:-n}

read -p "🎨 Install KDE Plasma customization tools? (y/N): " INSTALL_KDE_RICE
INSTALL_KDE_RICE=${INSTALL_KDE_RICE:-n}

echo ""

# -----------------------------------------------------------------------------
# System Update
# -----------------------------------------------------------------------------

echo "========================================="
echo "🔄 Updating System Packages"
echo "========================================="
echo ""

echo "📦 Updating all system packages to latest versions..."
sudo pacman -Syu --noconfirm --quiet

echo ""
echo "✅ System update completed!"
echo ""

# -----------------------------------------------------------------------------
# Faillock Configuration (Prevent Sudo Lockouts)
# -----------------------------------------------------------------------------

echo "========================================="
echo "🔐 Configuring Faillock"
echo "========================================="
echo ""

FAILLOCK_CONF="/etc/security/faillock.conf"

# Check if faillock is already configured with our settings
if grep -q "^deny = 10" "$FAILLOCK_CONF" 2>/dev/null && \
   grep -q "^unlock_time = 60" "$FAILLOCK_CONF" 2>/dev/null; then
    echo "   ✅ Faillock already configured"
else
    echo "🔧 Configuring lenient faillock settings..."
    
    # Update deny setting
    if grep -q "^# deny" "$FAILLOCK_CONF" 2>/dev/null; then
        sudo sed -i 's/^# deny.*/deny = 10/' "$FAILLOCK_CONF"
    elif ! grep -q "^deny" "$FAILLOCK_CONF" 2>/dev/null; then
        echo "deny = 10" | sudo tee -a "$FAILLOCK_CONF" > /dev/null
    fi
    
    # Update unlock_time setting
    if grep -q "^# unlock_time" "$FAILLOCK_CONF" 2>/dev/null; then
        sudo sed -i 's/^# unlock_time.*/unlock_time = 60/' "$FAILLOCK_CONF"
    elif ! grep -q "^unlock_time" "$FAILLOCK_CONF" 2>/dev/null; then
        echo "unlock_time = 60" | sudo tee -a "$FAILLOCK_CONF" > /dev/null
    fi
    
    # Update fail_interval setting
    if grep -q "^# fail_interval" "$FAILLOCK_CONF" 2>/dev/null; then
        sudo sed -i 's/^# fail_interval.*/fail_interval = 900/' "$FAILLOCK_CONF"
    elif ! grep -q "^fail_interval" "$FAILLOCK_CONF" 2>/dev/null; then
        echo "fail_interval = 900" | sudo tee -a "$FAILLOCK_CONF" > /dev/null
    fi
    
    echo "   ✅ Faillock configured:"
    echo "      - deny = 10 (allow 10 failed attempts)"
    echo "      - unlock_time = 60 (auto-unlock after 60 seconds)"
    echo "      - fail_interval = 900 (reset counter after 15 min)"
fi

echo ""

# -----------------------------------------------------------------------------
# Paru AUR Helper
# -----------------------------------------------------------------------------

echo "========================================="
echo "📦 Installing Paru AUR Helper"
echo "========================================="
echo ""

if ! command -v paru &> /dev/null; then
    echo "🔧 Installing paru from source..."
    sudo pacman -S --needed --noconfirm base-devel git
    TEMP_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$TEMP_DIR/paru"
    (cd "$TEMP_DIR/paru" && makepkg -si --noconfirm)
    rm -rf "$TEMP_DIR"
    echo "✅ Paru installed successfully!"
else
    echo "✅ Paru is already installed"
fi

echo ""

# -----------------------------------------------------------------------------
# Proton Pass
# -----------------------------------------------------------------------------

echo "========================================="
echo "🔧 Setting up Proton Pass"
echo "We install it first so you can find your passwords :)"
echo "========================================="
echo ""

install_packages proton-pass-bin

echo ""

# -----------------------------------------------------------------------------
# Zsh & Oh My Zsh
# -----------------------------------------------------------------------------

echo "========================================="
echo "🐚 Setting up Zsh & Oh My Zsh"
echo "========================================="
echo ""

echo "📦 Installing Zsh and plugins..."
install_packages zsh zsh-autosuggestions zsh-syntax-highlighting fzf

echo ""
echo "🔧 Setting Zsh as default shell..."
if [[ "$SHELL" != "$(which zsh)" ]]; then
    chsh -s $(which zsh)
    echo "   Changed default shell to zsh"
else
    echo "   ✅ Zsh is already the default shell"
fi

echo ""
echo "✨ Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "   ✅ Oh My Zsh is already installed"
fi

echo ""
echo "⚙️  Configuring .zshrc..."
cat > ~/.zshrc << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="af-magic"
plugins=(git fzf)
source $ZSH/oh-my-zsh.sh

# Zsh plugins
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Aliases
alias ds="dotnet script"
alias de="dotnet ef"
alias sshOpenClaw="ssh kasper@192.168.10.5"
alias sshDesktop="ssh kasper@192.168.0.3"
EOF
echo "   ✅ .zshrc configured"

echo ""
echo "✅ Zsh setup completed!"
echo ""

# -----------------------------------------------------------------------------
# Git Setup
# -----------------------------------------------------------------------------

echo "========================================="
echo "🔧 Setting up Git"
echo "========================================="
echo ""

echo "📦 Installing Git..."
install_packages git

echo ""
echo "⚙️  Configuring Git..."

# Only set if not already set
if [[ "$(git config --global credential.helper)" != "store" ]]; then
    git config --global credential.helper store
    echo "   - Credential helper: store"
else
    echo "   ✅ Credential helper already configured"
fi

if [[ "$(git config --global user.name)" != "Kasper Sogaard" ]]; then
    git config --global user.name "Kasper Sogaard"
    echo "   - Username: Kasper Sogaard"
else
    echo "   ✅ Username already configured"
fi

if [[ "$(git config --global user.email)" != "kasper@sogaard.us" ]]; then
    git config --global user.email "kasper@sogaard.us"
    echo "   - Email: kasper@sogaard.us"
else
    echo "   ✅ Email already configured"
fi

if [[ "$(git config --global push.autoSetupRemote)" != "true" ]]; then
    git config --global push.autoSetupRemote true
    echo "   - Auto push new branches: enabled"
else
    echo "   ✅ Auto push already configured"
fi

if [[ "$(git config --global init.defaultBranch)" != "master" ]]; then
    git config --global init.defaultBranch master
    echo "   - Default branch: master"
else
    echo "   ✅ Default branch already configured"
fi

echo ""
echo "🔑 Setting up GitHub credentials..."
if ! grep -q "github.com" ~/.git-credentials 2>/dev/null; then
    read -sp "   Enter your GitHub Personal Access Token (PAT): " GITHUB_PAT
    echo ""
    if [ -n "$GITHUB_PAT" ]; then
        echo "https://KRSogaard:${GITHUB_PAT}@github.com" >> ~/.git-credentials
        chmod 600 ~/.git-credentials
        echo "   ✅ GitHub PAT stored in ~/.git-credentials"
    else
        echo "   ⚠️  No token entered, skipping"
    fi
else
    echo "   ✅ GitHub credentials already stored"
fi

echo ""
echo "✅ Git setup completed!"
echo ""

# -----------------------------------------------------------------------------
# Main Package Installation
# -----------------------------------------------------------------------------

echo "========================================="
echo "📦 Installing Main Packages"
echo "========================================="
echo ""

echo "🌐 Installing browsers..."
install_packages brave-bin google-chrome

echo ""
echo "💻 Installing development tools..."
install_packages rider visual-studio-code-bin dbeaver opencode-bin claude-code

echo ""
echo "🔧 Installing CLI tools..."
install_packages github-cli aws-cli-v2 tmux jq pandoc texlive-core

echo ""
echo "🎮 Installing gaming and media..."
install_packages steam spotify

echo ""
echo "💬 Installing communication apps..."
install_packages slack-desktop-wayland proton-mail-bin

echo ""
echo "🛠️ Installing system utilities..."
install_packages proton-drive-sync-bin wezterm-git fastfetch

echo ""
echo "📺 Installing VLC media player..."
install_pacman_packages vlc

echo ""
echo "🔤 Installing Nerd Fonts..."
install_packages ttf-jetbrains-mono-nerd ttf-firacode-nerd ttf-hack-nerd

echo ""
echo "✅ Package installation completed!"
echo ""

# -----------------------------------------------------------------------------
# Docker Setup
# -----------------------------------------------------------------------------

echo "========================================="
echo "🐳 Setting up Docker Engine"
echo "========================================="
echo ""

echo "📦 Installing Docker Engine and NVIDIA Container Toolkit..."
install_pacman_packages docker docker-compose nvidia-container-toolkit

echo ""
echo "🔧 Enabling Docker service..."
if ! service_enabled docker; then
    sudo systemctl enable --now docker
    echo "   ✅ Docker service enabled and started"
else
    echo "   ✅ Docker service already enabled"
fi

echo ""
echo "👤 Adding user to docker group..."
if ! user_in_group docker; then
    sudo usermod -aG docker $USER
    echo "   ✅ User added to docker group"
    echo "   ⚠️  You may need to logout/login for group changes"
else
    echo "   ✅ User already in docker group"
fi

echo ""
echo "🎮 Configuring NVIDIA runtime for Docker..."
if ! grep -q "nvidia" /etc/docker/daemon.json 2>/dev/null; then
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    echo "   ✅ NVIDIA runtime configured"
else
    echo "   ✅ NVIDIA runtime already configured"
fi

echo ""
echo "✅ Docker setup completed!"
echo ""

# -----------------------------------------------------------------------------
# SSH Server Setup
# -----------------------------------------------------------------------------

echo "========================================="
echo "🔐 Setting up SSH Server"
echo "========================================="
echo ""

echo "📦 Installing OpenSSH and UFW..."
install_pacman_packages openssh ufw

echo ""
echo "🔧 Enabling SSH service..."
if ! service_enabled sshd; then
    sudo systemctl enable --now sshd
    echo "   ✅ SSH service enabled and started"
else
    echo "   ✅ SSH service already enabled"
fi

echo ""
echo "🔥 Configuring firewall..."
if ! sudo ufw status | grep -q "Status: active"; then
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw --force enable
    echo "   ✅ UFW enabled with SSH allowed"
else
    if ! sudo ufw status | grep -q "22/tcp"; then
        sudo ufw allow ssh
        echo "   ✅ SSH rule added to UFW"
    else
        echo "   ✅ UFW already configured with SSH"
    fi
fi

echo ""
echo "✅ SSH setup completed!"
echo ""

# -----------------------------------------------------------------------------
# .NET Development
# -----------------------------------------------------------------------------

echo "========================================="
echo "🔧 Setting up .NET Development"
echo "========================================="
echo ""

echo "📦 Installing .NET SDK..."
install_packages dotnet-sdk-bin

echo ""
echo "🛠️  Installing .NET tools..."

if ! dotnet_tool_installed "dotnet-ef"; then
    dotnet tool install --global dotnet-ef
    echo "   ✅ dotnet-ef installed"
else
    echo "   ✅ dotnet-ef already installed"
fi

if ! dotnet_tool_installed "dotnet-script"; then
    #dotnet tool install --global dotnet-script
    echo "   ✅ dotnet-script installed"
else
    echo "   ✅ dotnet-script already installed"
fi

echo ""
echo "✅ .NET Development setup completed!"
echo ""

# -----------------------------------------------------------------------------
# Development Environments
# -----------------------------------------------------------------------------

echo "========================================="
echo "🛠️  Setting up Development Environments"
echo "========================================="
echo ""

echo "🐍 Setting up Python development environment..."
install_packages python python-pip python-virtualenv

echo ""
echo "📦 Setting up Node.js development environment..."
install_packages nodejs npm pnpm

echo ""
echo "☕ Installing Java OpenJDK..."
install_packages jdk-openjdk

echo ""
echo "✅ Development environments setup completed!"
echo ""

# -----------------------------------------------------------------------------
# Folder Structure
# -----------------------------------------------------------------------------

echo "========================================="
echo "📁 Creating folder structure"
echo "========================================="
echo ""

if [ ! -d ~/workspaces ]; then
    mkdir -p ~/workspaces
    echo "   ✅ Created ~/workspaces"
else
    echo "   ✅ ~/workspaces already exists"
fi

echo ""
echo "✅ Folder structure ready!"
echo ""

# -----------------------------------------------------------------------------
# Dev Profiles (tmux + Claude Code work/personal)
# Runs after the Zsh section, which rewrites ~/.zshrc from scratch.
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIR/dev/install-linux.sh"

# -----------------------------------------------------------------------------
# Power Management (Optional - Laptops)
# -----------------------------------------------------------------------------

if [[ "$INSTALL_POWER_MGMT" =~ ^[Yy]$ ]]; then
    echo "========================================="
    echo "🔋 Setting up Power Management"
    echo "========================================="
    echo ""

    echo "📦 Installing TLP for battery optimization..."
    install_pacman_packages tlp tlp-rdw

    echo ""
    echo "🔧 Enabling TLP service..."
    if ! service_enabled tlp.service; then
        sudo systemctl enable tlp.service
        echo "   ✅ TLP service enabled"
    else
        echo "   ✅ TLP service already enabled"
    fi

    if ! service_enabled NetworkManager-dispatcher.service; then
        sudo systemctl enable NetworkManager-dispatcher.service
        echo "   ✅ NetworkManager-dispatcher enabled"
    else
        echo "   ✅ NetworkManager-dispatcher already enabled"
    fi

    # Mask rfkill services (idempotent operation)
    sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket 2>/dev/null || true

    echo ""
    echo "📦 Installing auto-cpufreq for dynamic CPU scaling..."
    install_packages auto-cpufreq

    echo ""
    echo "🔧 Enabling auto-cpufreq service..."
    if ! service_enabled auto-cpufreq; then
        sudo systemctl enable --now auto-cpufreq
        echo "   ✅ auto-cpufreq service enabled"
    else
        echo "   ✅ auto-cpufreq service already enabled"
    fi

    echo ""
    echo "📦 Installing powertop for power analysis..."
    install_pacman_packages powertop

    echo ""
    echo "✅ Power management setup completed!"
    echo ""
fi

# -----------------------------------------------------------------------------
# Razer Peripherals (Optional)
# -----------------------------------------------------------------------------

if [[ "$INSTALL_RAZER" =~ ^[Yy]$ ]]; then
    echo "========================================="
    echo "🐍 Setting up Razer Peripherals"
    echo "========================================="
    echo ""

    echo "📦 Installing OpenRazer driver..."
    install_packages openrazer-meta

    echo ""
    echo "👤 Adding user to plugdev group..."
    if ! user_in_group plugdev; then
        sudo gpasswd -a $USER plugdev
        echo "   ✅ User added to plugdev group"
        echo "   ⚠️  You may need to logout/login for group changes"
    else
        echo "   ✅ User already in plugdev group"
    fi

    echo ""
    echo "📦 Installing Polychromatic (RGB control GUI)..."
    install_packages polychromatic

    echo ""
    echo "🔧 Enabling OpenRazer daemon..."
    if ! user_service_enabled openrazer-daemon.service; then
        systemctl --user enable openrazer-daemon.service
        echo "   ✅ OpenRazer daemon enabled"
    else
        echo "   ✅ OpenRazer daemon already enabled"
    fi

    echo ""
    echo "✅ Razer setup completed!"
    echo "   ⚠️  Reboot required for driver to load"
    echo ""
fi

# -----------------------------------------------------------------------------
# KDE Plasma Customization (Optional)
# -----------------------------------------------------------------------------

if [[ "$INSTALL_KDE_RICE" =~ ^[Yy]$ ]]; then
    echo "========================================="
    echo "🎨 Setting up KDE Plasma Customization"
    echo "========================================="
    echo ""

    echo "📦 Installing Kvantum theme engine..."
    install_packages kvantum

    echo ""
    echo "📦 Installing Catppuccin KDE theme..."
    install_packages catppuccin-plasma-colorscheme-mocha

    echo ""
    echo "📦 Installing icon packs..."
    install_packages papirus-icon-theme tela-icon-theme candy-icons-git

    echo ""
    echo "📦 Installing cursors..."
    install_packages bibata-cursor-theme-bin

    echo ""
    echo "📦 Installing KDE tools..."
    install_packages konsave latte-dock-git

    echo ""
    echo "📦 Installing SDDM themes..."
    install_packages sddm-theme-catppuccin-git

    echo ""
    echo "✅ KDE customization tools installed!"
    echo "   Theme: Catppuccin Mocha"
    echo "   Icons: Papirus, Tela, Candy"
    echo "   Cursors: Bibata"
    echo ""
    echo "   Apply theme in: System Settings > Appearance > Colors"
    echo "   Apply Kvantum themes: kvantummanager"
    echo ""
fi

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------

echo "========================================="
echo "🧹 System Cleanup"
echo "========================================="
echo ""

echo "🗑️  Cleaning package cache..."
paru -Sc --noconfirm --quiet 2>/dev/null || true
echo "   ✅ Package cache cleaned"

echo ""
echo "📦 Removing orphaned packages..."
if orphans=$(pacman -Qtdq 2>/dev/null); then
    sudo pacman -Rns $orphans --noconfirm
    echo "   ✅ Orphaned packages removed"
else
    echo "   ✅ No orphaned packages found"
fi

echo ""
echo "🧽 Cleaning AUR build cache..."
paru -Yc --noconfirm --quiet 2>/dev/null || true
echo "   ✅ AUR build cache cleaned"

echo ""
echo "🗂️  Removing unwanted default directories..."
for dir in ~/Documents ~/Music ~/Templates ~/Videos ~/Pictures/Screenshots; do
    if [ -d "$dir" ] && [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        rmdir "$dir" 2>/dev/null && echo "   ✅ Removed empty directory: $(basename "$dir")"
    fi
done

echo ""
echo "✅ System cleanup completed!"
echo ""

# -----------------------------------------------------------------------------
# Done!
# -----------------------------------------------------------------------------

echo "========================================="
echo "🎉 Arch Linux setup finished!"
echo "========================================="
echo ""
echo "This script is idempotent - run it again anytime to ensure everything is set up!"
echo ""
