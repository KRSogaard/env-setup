#!/bin/bash

# =============================================================================
# Shared dev-profile deploy steps. Sourced by dev/install-linux.sh and
# dev/install-mac.sh after they have installed the platform packages.
# Everything here is idempotent: re-running just updates to the repo version.
# =============================================================================

DEV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%s)"
ZSH_BLOCK="$HOME/.config/zsh/dev-profiles.zsh"
SOURCE_LINE='[ -f "$HOME/.config/zsh/dev-profiles.zsh" ] && source "$HOME/.config/zsh/dev-profiles.zsh"'

# Copy $1 to $2, backing up $2 first if it exists and differs.
deploy_file() {
    local src="$1" dst="$2" mode="$3"
    # A symlink (e.g. ~/.local/bin/gwt from the old personal-tools repo) is
    # replaced by a real copy rather than followed.
    if [ -L "$dst" ]; then
        rm "$dst"
        echo "   🔗 Removed symlink ${dst/#$HOME/\~}"
    fi
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        echo "   ✅ ${dst/#$HOME/\~} up to date"
        return
    fi
    if [ -f "$dst" ]; then
        cp "$dst" "$dst.bak.$STAMP"
        echo "   📦 Backed up ${dst/#$HOME/\~} -> ${dst/#$HOME/\~}.bak.$STAMP"
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    [ -n "$mode" ] && chmod "$mode" "$dst"
    echo "   ✅ ${dst/#$HOME/\~} updated"
}

# Claude Code's native installer; skipped when claude is already on PATH.
install_claude_code() {
    if command -v claude &>/dev/null; then
        echo "   ✅ Claude Code already installed ($(command -v claude))"
    else
        curl -fsSL https://claude.ai/install.sh | bash
        echo "   ✅ Claude Code installed"
    fi
}

deploy_helper_scripts() {
    echo ""
    echo "🔧 Installing helper scripts to ~/.local/bin..."
    for script in "$DEV_DIR"/bin/*; do
        deploy_file "$script" "$HOME/.local/bin/$(basename "$script")" 755
    done
}

deploy_tmux() {
    echo ""
    echo "🖥️  Installing tmux config..."
    deploy_file "$DEV_DIR/tmux.conf" "$HOME/.tmux.conf"
}

# The block lives in its own file; ~/.zshrc only gets one source line.
# An older inline copy of the block in ~/.zshrc is cut out and replaced by
# that line, so nothing is defined twice.
deploy_zsh() {
    echo ""
    echo "🐚 Installing zsh dev-profiles block..."
    deploy_file "$DEV_DIR/dev-profiles.zsh" "$ZSH_BLOCK"

    touch ~/.zshrc
    if grep -q '^# dev profiles: work / personal' ~/.zshrc; then
        cp ~/.zshrc ~/.zshrc.bak.$STAMP
        python3 - "$HOME/.zshrc" "$SOURCE_LINE" <<'PY'
import sys
path, source_line = sys.argv[1], sys.argv[2]
lines = open(path).read().split("\n")
start = next(i for i, l in enumerate(lines) if l.startswith("# dev profiles: work / personal"))
# The header is framed by ═ rulers; include the one above it.
if start > 0 and lines[start - 1].startswith("# ═"):
    start -= 1
end = next(i for i in range(start, len(lines)) if lines[i].startswith("alias dev-status="))
out = lines[:start] + [source_line] + lines[end + 1:]
out = [l for l in out if l != "# (bun PATH/completions are set in the managed dev-profiles block above)"]
open(path, "w").write("\n".join(out))
PY
        echo "   ✅ Moved inline block out of ~/.zshrc (backup: ~/.zshrc.bak.$STAMP)"
    fi

    # gwt used to come from the personal-tools repo; its wrapper now lives in
    # dev-profiles.zsh.
    if grep -q '^source ".*personal-tools/gwt/gwt.sh"$' ~/.zshrc; then
        cp ~/.zshrc ~/.zshrc.bak.$STAMP
        sed -i.tmp '/^source ".*personal-tools\/gwt\/gwt.sh"$/d' ~/.zshrc && rm -f ~/.zshrc.tmp
        echo "   ✅ Removed personal-tools gwt source line from ~/.zshrc (backup: ~/.zshrc.bak.$STAMP)"
    fi

    if grep -qF '.config/zsh/dev-profiles.zsh' ~/.zshrc; then
        echo "   ✅ ~/.zshrc sources ${ZSH_BLOCK/#$HOME/\~}"
    else
        printf '\n%s\n' "$SOURCE_LINE" >> ~/.zshrc
        echo "   ✅ Added source line to ~/.zshrc"
    fi
}

# Repo values win for every key claude-settings.json defines; keys only the
# local file has (theme, autoMode, modelSettings, ...) are kept.
deploy_claude_settings() {
    echo ""
    echo "⚙️  Configuring Claude Code settings..."
    local node_bin rendered cfg target merged
    node_bin="$(command -v node || echo node)"
    rendered="$(mktemp)"
    sed -e "s#__HOME__#$HOME#g" -e "s#__NODE__#$node_bin#g" "$DEV_DIR/claude-settings.json" > "$rendered"

    for cfg in "$HOME/.claude" "$HOME/.claude-personal"; do
        target="$cfg/settings.json"
        mkdir -p "$cfg"
        if [ ! -f "$target" ]; then
            cp "$rendered" "$target"
            echo "   ✅ ${target/#$HOME/\~} created"
            continue
        fi
        merged="$(mktemp)"
        jq -s '.[0] * .[1]' "$target" "$rendered" > "$merged"
        if cmp -s <(jq -S . "$target") <(jq -S . "$merged"); then
            echo "   ✅ ${target/#$HOME/\~} up to date"
            rm -f "$merged"
        else
            cp "$target" "$target.bak.$STAMP"
            mv "$merged" "$target"
            echo "   ✅ ${target/#$HOME/\~} updated (backup: settings.json.bak.$STAMP)"
        fi
    done
    rm -f "$rendered"
}

create_workspaces() {
    echo ""
    echo "📁 Creating workspace folders..."
    for dir in ~/workspaces/magicdoor ~/workspaces/personal; do
        if [ -d "$dir" ]; then
            echo "   ✅ ${dir/#$HOME/\~} already exists"
        else
            mkdir -p "$dir"
            echo "   ✅ Created ${dir/#$HOME/\~}"
        fi
    done
}

# API keys and the SSH key live in the private env-setup-secrets repo, cloned
# next to this one. Skipped (with a hint) when it is not there.
deploy_secrets() {
    echo ""
    local secrets_dir
    secrets_dir="$(dirname "$(dirname "$DEV_DIR")")/env-setup-secrets"
    if [ -x "$secrets_dir/install.sh" ]; then
        "$secrets_dir/install.sh"
    else
        echo "🔐 No secrets repo at ${secrets_dir/#$HOME/\~} — skipping. To add API keys + SSH key:"
        echo "   git clone https://github.com/KRSogaard/env-setup-secrets.git ${secrets_dir/#$HOME/\~} && ${secrets_dir/#$HOME/\~}/install.sh"
    fi
}

deploy_all() {
    deploy_helper_scripts
    deploy_tmux
    deploy_zsh
    deploy_claude_settings
    create_workspaces
    deploy_secrets

    echo ""
    echo "✅ Dev profiles ready! Next:"
    echo "   exec zsh"
    echo "   dev-work      -> claude -> /login as kasper@magicdoor.com"
    echo "   dev-personal  -> claude -> /login as kasper@sogaard.us"
    echo "   dev-status    # confirms which account is really logged in"
    echo ""
}
