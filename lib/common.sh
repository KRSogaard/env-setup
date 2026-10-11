#!/bin/bash

# =============================================================================
# Helpers shared by every installer in this repo. Sourced, never run.
#
# The rule all of them follow: the repo is the source of truth, and running
# any installer again converges the machine to it. Files the repo owns are
# deployed whole (backed up as *.bak.<epoch> when they differ); files other
# tools also write to, like ~/.zshrc, only get one source line from us.
# =============================================================================

ENV_SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# What the last run deployed, so the next run can remove what the repo dropped.
ENV_SETUP_STATE="$HOME/.local/share/env-setup"
# Answers to install-time questions, reused as defaults on the next run.
ENV_SETUP_CONFIG="$HOME/.config/env-setup"
# One stamp per install run, shared with child installers (dev/, secrets).
export STAMP="${STAMP:-$(date +%s)}"

# Back up $1 as $1.bak.<STAMP>, once per run: several edits to the same file
# in one run must not overwrite the copy of the original.
backup_file() {
    [ -f "$1" ] && [ ! -e "$1.bak.$STAMP" ] && cp "$1" "$1.bak.$STAMP"
    return 0
}

# Copy $1 to $2 (optional mode $3), backing up $2 first if it differs.
# Sets DEPLOY_CHANGED=1 when the file was written, 0 when already current.
deploy_file() {
    local src="$1" dst="$2" mode="${3:-}"
    DEPLOY_CHANGED=0
    # A symlink (e.g. an old ~/.local/bin/gwt pointing into another repo) is
    # replaced by a real copy rather than followed.
    if [ -L "$dst" ]; then
        rm "$dst"
        echo "   🔗 Removed symlink ${dst/#$HOME/\~}"
    fi
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        [ -n "$mode" ] && chmod "$mode" "$dst"
        echo "   ✅ ${dst/#$HOME/\~} up to date"
        return
    fi
    if [ -f "$dst" ]; then
        backup_file "$dst"
        echo "   📦 Backed up ${dst/#$HOME/\~} -> ${dst/#$HOME/\~}.bak.$STAMP"
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    [ -n "$mode" ] && chmod "$mode" "$dst"
    DEPLOY_CHANGED=1
    echo "   ✅ ${dst/#$HOME/\~} updated"
}

# Ensure ~/.zshrc contains the exact line $1. With "top" as $2 it is inserted
# as the first line (for config that must load before everything else).
ensure_zshrc_line() {
    local line="$1" where="${2:-bottom}"
    touch ~/.zshrc
    if grep -qxF "$line" ~/.zshrc; then
        return
    fi
    backup_file ~/.zshrc
    if [ "$where" = top ]; then
        local rest
        rest="$(cat ~/.zshrc)"
        printf '%s\n%s\n' "$line" "$rest" > ~/.zshrc
    else
        printf '\n%s\n' "$line" >> ~/.zshrc
    fi
    echo "   ✅ Added to ~/.zshrc: $line"
}

# Ask a y/N question once per machine. The answer is saved in
# ~/.config/env-setup/<file>.env and offered as the default next time; with no
# terminal (unattended re-run) the saved answer is used without asking.
ask_saved() {
    local file="$ENV_SETUP_CONFIG/$1.env" var="$2" question="$3"
    local saved answer
    saved="$( [ -f "$file" ] && sed -n "s/^$var=//p" "$file" )"
    saved="${saved:-n}"
    if [ -t 0 ]; then
        local hint="y/N"; [ "$saved" = y ] && hint="Y/n"
        read -r -p "$question ($hint): " answer
        answer="${answer:-$saved}"
    else
        answer="$saved"
    fi
    [[ "$answer" =~ ^[Yy] ]] && answer=y || answer=n
    mkdir -p "$ENV_SETUP_CONFIG"
    touch "$file"
    grep -v "^$var=" "$file" > "$file.tmp" || true
    echo "$var=$answer" >> "$file.tmp"
    mv "$file.tmp" "$file"
    printf -v "$var" '%s' "$answer"
}

# Run a one-time manual step ($1 = id) only if it has not been confirmed yet.
# The step is the remaining arguments; it is recorded once it succeeds.
once() {
    local id="$1"; shift
    local marker="$ENV_SETUP_STATE/done-$id"
    if [ -f "$marker" ]; then
        echo "   ✅ Already done ($id) — delete ${marker/#$HOME/\~} to redo"
        return
    fi
    "$@" && mkdir -p "$ENV_SETUP_STATE" && touch "$marker"
}

# -----------------------------------------------------------------------------
# Git
# -----------------------------------------------------------------------------

git_set() {
    local key="$1" value="$2"
    if [[ "$(git config --global "$key")" != "$value" ]]; then
        git config --global "$key" "$value"
        echo "   - $key = $value"
    else
        echo "   ✅ $key already $value"
    fi
}

# GitHub auth goes through the GitHub CLI, which keeps the token in the system
# keyring instead of plain text, and serves it to git. Needs gh installed.
setup_git() {
    echo "========================================="
    echo "🔧 Setting up Git"
    echo "========================================="
    echo ""
    git_set user.name "Kasper Sogaard"
    git_set user.email "kasper@sogaard.us"
    git_set push.autoSetupRemote true
    git_set init.defaultBranch master

    echo ""
    echo "🔑 GitHub auth (gh)..."
    if ! command -v gh &>/dev/null; then
        echo "   ⚠️  gh not installed — skipping GitHub auth"
        echo ""
        return
    fi
    # A GITHUB_TOKEN in the environment would shadow the keyring login.
    unset GITHUB_TOKEN GH_TOKEN
    if gh auth status -h github.com &>/dev/null; then
        echo "   ✅ gh is logged in to github.com"
    elif [ -t 0 ]; then
        gh auth login -h github.com -p https -w || echo "   ⚠️  gh login failed — re-run to retry"
    else
        echo "   ⚠️  No terminal — run: gh auth login"
    fi
    if gh auth status -h github.com &>/dev/null; then
        gh auth setup-git -h github.com
        echo "   ✅ git uses gh for github.com"
        # The PAT the old installers stored in plain text is no longer needed.
        if grep -q "github.com" ~/.git-credentials 2>/dev/null; then
            backup_file ~/.git-credentials
            grep -v "github.com" ~/.git-credentials.bak.$STAMP > ~/.git-credentials || true
            chmod 600 ~/.git-credentials
            echo "   ✅ Removed the plain-text GitHub token from ~/.git-credentials (backup: ~/.git-credentials.bak.$STAMP)"
        fi
    fi
    echo ""
}

# Key-only SSH (system/sshd-env-setup.conf). Skipped while the account has no
# authorized key, so this can never lock you out; the config is validated with
# `sshd -t` before sshd is reloaded.
harden_sshd() {
    echo "🔐 Hardening sshd (key-only login)..."
    local src="$ENV_SETUP_DIR/system/sshd-env-setup.conf"
    local dst="/etc/ssh/sshd_config.d/10-env-setup.conf"
    if [ ! -d /etc/ssh/sshd_config.d ]; then
        echo "   ⚠️  No /etc/ssh/sshd_config.d — skipping"
        return
    fi
    if [ ! -s "$HOME/.ssh/authorized_keys" ]; then
        echo "   ⚠️  ~/.ssh/authorized_keys is empty — skipping, so password login keeps working"
        echo "      Add a key (ssh-copy-id from your laptop) and re-run."
        return
    fi
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        echo "   ✅ $dst up to date"
        return
    fi
    sudo install -m 644 "$src" "$dst"
    if ! sudo sshd -t; then
        sudo rm -f "$dst"
        echo "   ❌ sshd rejected the config — removed it again"
        return 1
    fi
    sudo systemctl reload sshd 2>/dev/null || sudo systemctl reload ssh 2>/dev/null || true
    echo "   ✅ $dst updated, sshd reloaded"
}

# -----------------------------------------------------------------------------
# Zsh: login shell, Oh My Zsh, and the repo's base config
# -----------------------------------------------------------------------------

# Lines the old installers wrote straight into ~/.zshrc. base.zsh now owns
# them, so exact copies are removed to keep them from loading twice (and to
# stop a second oh-my-zsh load from re-adding its `gwt` alias over our gwt).
LEGACY_ZSHRC_LINES=(
    '# Non-login shells (e.g. `ssh host zsh -ic dev-work`) skip /etc/profile, so LANG'
    '# is unset and tmux attaches without UTF-8, rendering » and emoji as "_".'
    'export LANG="${LANG:-en_US.UTF-8}"'
    'export ZSH="$HOME/.oh-my-zsh"'
    'ZSH_THEME="af-magic"'
    'plugins=(git)'
    'plugins=(git fzf)'
    'source $ZSH/oh-my-zsh.sh'
    '# Zsh plugins'
    'source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh'
    'source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'
    '# Aliases'
    'alias ds="dotnet script"'
    'alias de="dotnet ef"'
    'alias sshOpenClaw="ssh kasper@192.168.10.5"'
    'alias sshDesktop="ssh kasper@192.168.0.3"'
    'export PATH="$PATH:$HOME/.dotnet/tools"'
    'eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true'
    'eval "$(/opt/homebrew/bin/brew shellenv)"'
    '# Host badge on the prompt line (after af-magic'"'"'s dashed separator), so this'
    '# box is never mistaken for the local machine.'
    '_host_badge=$'"'"'\n'"'"'"%B%F{213}[%m]%f%b "'
    'PS1=${PS1/$'"'"'\n'"'"'/$_host_badge}'
    'unset _host_badge'
)

# Make zsh (from PATH) the login shell.
set_login_shell_zsh() {
    local zsh_path
    zsh_path="$(command -v zsh)"
    local current
    current="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)"
    [ -z "$current" ] && current="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
    if [ "$current" = "$zsh_path" ] || [ "$(basename "$current")" = zsh ]; then
        echo "   ✅ zsh is already the login shell"
    else
        grep -qxF "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells > /dev/null
        chsh -s "$zsh_path"
        echo "   ✅ Login shell changed to $zsh_path (takes effect on next login)"
    fi
}

install_oh_my_zsh() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "   ✅ Oh My Zsh already installed (it updates itself)"
    else
        # KEEP_ZSHRC: never let the Oh My Zsh installer replace ~/.zshrc.
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        echo "   ✅ Oh My Zsh installed"
    fi
}

# Deploy shell/base.zsh to ~/.config/zsh/base.zsh and source it from the top of
# ~/.zshrc, removing the inline copies older installers wrote.
deploy_zsh_base() {
    echo "⚙️  Base zsh config..."
    deploy_file "$ENV_SETUP_DIR/shell/base.zsh" "$HOME/.config/zsh/base.zsh"

    touch ~/.zshrc
    local cleaned
    cleaned="$(mktemp)"
    python3 - "$HOME/.zshrc" "$cleaned" "${LEGACY_ZSHRC_LINES[@]}" <<'PY'
import sys
path, out_path, legacy = sys.argv[1], sys.argv[2], set(sys.argv[3:])
lines = open(path).read().split("\n")
kept = [l for l in lines if l not in legacy]
# Collapse the blank runs left behind.
out = []
for l in kept:
    if l.strip() == "" and out and out[-1].strip() == "":
        continue
    out.append(l)
open(out_path, "w").write("\n".join(out))
PY
    if cmp -s "$cleaned" ~/.zshrc; then
        rm -f "$cleaned"
    else
        backup_file ~/.zshrc
        cat "$cleaned" > ~/.zshrc
        rm -f "$cleaned"
        echo "   ✅ Removed lines now owned by base.zsh from ~/.zshrc (backup: ~/.zshrc.bak.$STAMP)"
    fi
    ensure_zshrc_line '[ -f "$HOME/.config/zsh/base.zsh" ] && source "$HOME/.config/zsh/base.zsh"' top
}
