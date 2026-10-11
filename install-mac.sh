#!/bin/bash

# =============================================================================
# Idempotent macOS Setup Script (Clean MacBook Pro)
# Can be run multiple times - only installs/configures what's missing
# =============================================================================

set -e

echo "========================================="
echo "🏗️  macOS Setup Script"
echo "========================================="
echo ""

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

# Check if a brew formula is installed
brew_installed() {
    brew list --formula "$1" &> /dev/null 2>&1
}

# Check if a brew cask is installed
cask_installed() {
    brew list --cask "$1" &> /dev/null 2>&1
}

# Install brew formulas only if not already installed
install_formulas() {
    local packages=("$@")
    local to_install=()

    for pkg in "${packages[@]}"; do
        if ! brew_installed "$pkg"; then
            to_install+=("$pkg")
        fi
    done

    if [ ${#to_install[@]} -gt 0 ]; then
        echo "   Installing: ${to_install[*]}"
        brew install "${to_install[@]}"
    else
        echo "   ✅ All formulas already installed"
    fi
}

# Install brew casks only if not already installed
install_casks() {
    local casks=("$@")
    local to_install=()

    for cask in "${casks[@]}"; do
        if ! cask_installed "$cask"; then
            to_install+=("$cask")
        fi
    done

    if [ ${#to_install[@]} -gt 0 ]; then
        echo "   Installing: ${to_install[*]}"
        brew install --cask "${to_install[@]}"
    else
        echo "   ✅ All casks already installed"
    fi
}

# Install Mac App Store apps via mas (idempotent)
install_mas_app() {
    local app_id="$1"
    local app_name="$2"
    if mas list | grep -q "^$app_id "; then
        echo "   ✅ $app_name already installed"
    else
        echo "   Installing $app_name..."
        if ! mas install "$app_id" 2>/dev/null; then
            echo "   ⚠️  Automatic install failed. Opening App Store..."
            open "macappstore://itunes.apple.com/app/id${app_id}"
            read -p "   Install $app_name from the App Store, then press Enter to continue..."
        fi
    fi
}

# Check if a dotnet tool is installed
dotnet_tool_installed() {
    dotnet tool list --global 2>/dev/null | grep -q "^$1 "
}

# -----------------------------------------------------------------------------
# Xcode Command Line Tools
# -----------------------------------------------------------------------------

echo "========================================="
echo "🔧 Xcode Command Line Tools"
echo "========================================="
echo ""

if ! xcode-select -p &> /dev/null; then
    echo "📦 Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "   ⚠️  A dialog will appear. Click 'Install' and wait for completion."
    echo "   Press Enter when the installation is finished."
    read -r
else
    echo "   ✅ Xcode Command Line Tools already installed"
fi

echo ""

# -----------------------------------------------------------------------------
# Homebrew
# -----------------------------------------------------------------------------

echo "========================================="
echo "🍺 Installing Homebrew"
echo "========================================="
echo ""

if ! command -v brew &> /dev/null; then
    echo "🔧 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add brew to PATH for Apple Silicon
    if [[ "$(uname -m)" == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    echo "   ✅ Homebrew installed"
else
    echo "   ✅ Homebrew already installed"
fi

echo ""

# -----------------------------------------------------------------------------
# Mac App Store CLI
# -----------------------------------------------------------------------------

echo "========================================="
echo "🏪 Installing Mac App Store CLI (mas)"
echo "========================================="
echo ""

install_formulas mas

echo ""

# -----------------------------------------------------------------------------
# Proton Pass
# -----------------------------------------------------------------------------

echo "========================================="
echo "🔧 Setting up Proton Pass"
echo "We install it first so you can find your passwords :)"
echo "========================================="
echo ""

install_casks proton-pass

echo ""

# -----------------------------------------------------------------------------
# Zsh & Oh My Zsh
# -----------------------------------------------------------------------------

echo "========================================="
echo "🐚 Setting up Oh My Zsh"
echo "========================================="
echo ""

echo "   ✅ Zsh is the default shell on macOS"

echo ""
echo "✨ Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "   ✅ Oh My Zsh is already installed"
fi

# Check if .zshrc needs updating
EXPECTED_THEME='ZSH_THEME="af-magic"'
if ! grep -q "$EXPECTED_THEME" ~/.zshrc 2>/dev/null; then
    echo ""
    echo "⚙️  Configuring .zshrc with minimal config..."
    cat > ~/.zshrc << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
export PATH="$PATH:$HOME/.dotnet/tools"
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
ZSH_THEME="af-magic"
plugins=(git)
source $ZSH/oh-my-zsh.sh
alias ds="dotnet script"
alias de="dotnet ef"
EOF
    echo "   ✅ .zshrc configured"
else
    echo "   ✅ .zshrc already configured"
fi

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

echo "⚙️  Configuring Git..."

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
install_casks brave-browser google-chrome

echo ""
echo "💻 Installing development tools..."
install_casks jetbrains-rider visual-studio-code dbeaver-community

echo ""
echo "🔧 Installing CLI tools..."
install_formulas gh awscli tmux jq pandoc fastfetch ollama

echo ""
echo "📄 Installing MacTeX (includes XeLaTeX for Pandoc)..."
install_casks mactex

echo ""
echo "🎮 Installing gaming and media..."
install_casks steam spotify

echo ""
echo "💬 Installing communication apps..."
install_casks slack proton-mail

echo ""
echo "🛠️ Installing system utilities..."
install_casks proton-drive wezterm

echo ""
echo "📺 Installing VLC media player..."
install_casks vlc

echo ""
echo "🔤 Installing Nerd Fonts..."
install_casks font-jetbrains-mono-nerd-font font-fira-code-nerd-font font-hack-nerd-font

echo ""
echo "✅ Package installation completed!"
echo ""

# -----------------------------------------------------------------------------
# Docker Desktop
# -----------------------------------------------------------------------------

echo "========================================="
echo "🐳 Setting up Docker Desktop"
echo "========================================="
echo ""

install_casks docker

echo ""
echo "   ℹ️  Open Docker Desktop from Applications to complete setup"
echo ""
echo "✅ Docker Desktop installed!"
echo ""

echo "🌐 Setting up Open WebUI (web interface for Ollama)..."
if ! docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^open-webui$"; then
    echo "   ℹ️  Make sure Docker Desktop is running before continuing."
    read -p "   Press Enter when Docker Desktop is ready..."
    docker run -d -p 5300:8080 --add-host=host.docker.internal:host-gateway --name open-webui --restart always ghcr.io/open-webui/open-webui:main
    echo "   ✅ Open WebUI running at http://localhost:5300"
else
    echo "   ✅ Open WebUI container already exists"
fi

echo ""

# -----------------------------------------------------------------------------
# Window Management & Utilities
# -----------------------------------------------------------------------------

echo "========================================="
echo "🪟 Installing Window Management & Utilities"
echo "========================================="
echo ""

echo "📦 Installing Magnet (window manager)..."
install_mas_app 441258766 "Magnet"

echo ""
echo "☕ Installing Caffeine..."
install_casks domzilla-caffeine

echo ""
echo "📦 Installing WhatsApp Messenger..."
install_mas_app 310633997 "WhatsApp Messenger"

echo ""
echo "📦 Installing Brother iPrint&Scan..."
install_mas_app 1193539993 "Brother iPrint&Scan"

echo ""
echo "📦 Installing AudioBooth..."
install_mas_app 6753017503 "AudioBooth"

echo ""
echo "✅ Utilities installed!"
echo ""

# -----------------------------------------------------------------------------
# Desktop Customization & Productivity
# -----------------------------------------------------------------------------

echo "========================================="
echo "✨ Installing Desktop Customization & Productivity"
echo "========================================="
echo ""

echo "🎬 Installing Backdrop (live wallpapers)..."
install_casks backdrop

echo ""
echo "🚀 Installing Raycast (Spotlight replacement)..."
install_casks raycast

echo ""
echo "🪟 Installing AltTab (window preview switcher)..."
install_casks alt-tab

echo ""
echo "📊 Installing Stats (system monitor)..."
install_casks stats

echo ""
echo "🙈 Installing Hidden Bar (menu bar cleanup)..."
install_casks hiddenbar

echo ""
echo "🖥️ Installing MonitorControl (external display control)..."
install_casks monitorcontrol

echo ""
echo "✅ Desktop customization installed!"
echo ""

# -----------------------------------------------------------------------------
# .NET Development
# -----------------------------------------------------------------------------

echo "========================================="
echo "🔧 Setting up .NET Development"
echo "========================================="
echo ""

echo "📦 Installing .NET SDK..."
install_casks dotnet-sdk

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
install_formulas python

echo ""
echo "📦 Setting up Node.js development environment..."
install_formulas node pnpm

echo ""
echo "☕ Installing Java OpenJDK..."
install_formulas openjdk

echo ""
echo "✅ Development environments setup completed!"
echo ""

# -----------------------------------------------------------------------------
# Dev Profiles (tmux + Claude Code work/personal)
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIR/dev/install-mac.sh"

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
# macOS Defaults
# -----------------------------------------------------------------------------

echo "========================================="
echo "⚙️  Configuring macOS Defaults"
echo "========================================="
echo ""

echo "🔧 Setting sensible macOS defaults..."

# Show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles -bool true 2>/dev/null && echo "   - Finder: show hidden files"

# Show path bar in Finder
defaults write com.apple.finder ShowPathbar -bool true 2>/dev/null && echo "   - Finder: show path bar"

# Show status bar in Finder
defaults write com.apple.finder ShowStatusBar -bool true 2>/dev/null && echo "   - Finder: show status bar"

# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false 2>/dev/null && echo "   - Keyboard: key repeat enabled"

# Fast key repeat rate
defaults write NSGlobalDomain KeyRepeat -int 2 2>/dev/null && echo "   - Keyboard: fast repeat rate"
defaults write NSGlobalDomain InitialKeyRepeat -int 15 2>/dev/null && echo "   - Keyboard: short delay until repeat"

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false 2>/dev/null && echo "   - Keyboard: auto-correct disabled"

# Restart Finder to apply changes
killall Finder 2>/dev/null || true

echo ""
echo "✅ macOS defaults configured!"
echo ""

# -----------------------------------------------------------------------------
# Screen Recording Permissions
# -----------------------------------------------------------------------------

echo "========================================="
echo "🔒 Screen Recording Permissions"
echo "========================================="
echo ""

echo "   macOS requires you to manually grant Screen Recording permission."
echo "   Please enable it for: Slack, Brave, Chrome, and Zoom."
echo ""
echo "   Opening Screen Recording settings..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
read -p "   Press Enter when you've enabled Screen Recording for all apps..."

echo ""
echo "✅ Screen recording permissions configured!"
echo ""

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------

echo "========================================="
echo "🧹 Cleanup"
echo "========================================="
echo ""

echo "🗑️  Cleaning Homebrew cache..."
brew cleanup --prune=all 2>/dev/null || true
echo "   ✅ Homebrew cache cleaned"

echo ""
echo "✅ Cleanup completed!"
echo ""

# -----------------------------------------------------------------------------
# Done!
# -----------------------------------------------------------------------------

echo "========================================="
echo "🎉 macOS setup finished!"
echo "========================================="
echo ""
echo "This script is idempotent - run it again anytime to ensure everything is set up!"
echo ""
echo "Notes:"
echo "  - Open Docker Desktop from Applications to complete Docker setup"
echo "  - Open Magnet from Applications and grant Accessibility permissions"
echo "  - Open KeepingYouAwake from the menu bar to keep your Mac awake"
echo "  - You may need to restart your terminal for all changes to take effect"
echo ""
