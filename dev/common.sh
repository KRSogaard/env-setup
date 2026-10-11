#!/bin/bash

# =============================================================================
# Shared dev-profile deploy steps. Sourced by dev/install-linux.sh and
# dev/install-mac.sh after they have installed the platform packages.
# Everything here is idempotent: re-running just updates to the repo version.
# =============================================================================

DEV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DEV_DIR/../lib/common.sh"
ZSH_BLOCK="$HOME/.config/zsh/dev-profiles.zsh"
SOURCE_LINE='[ -f "$HOME/.config/zsh/dev-profiles.zsh" ] && source "$HOME/.config/zsh/dev-profiles.zsh"'

# Claude Code's native installer (~/.local/bin/claude), which updates itself
# from then on. A claude from a package manager does not count.
install_claude_code() {
    if [ -x "$HOME/.local/bin/claude" ]; then
        echo "   ✅ Claude Code already installed (native, ~/.local/bin/claude)"
    else
        # The AUR package's /usr/bin/claude exports DISABLE_UPDATES=1, which
        # leaks into anything run from such a session and blocks this installer.
        curl -fsSL https://claude.ai/install.sh | env -u DISABLE_UPDATES -u DISABLE_INSTALLATION_CHECKS bash
        if [ -x "$HOME/.local/bin/claude" ]; then
            echo "   ✅ Claude Code installed (native)"
        else
            echo "   ⚠️  Native Claude Code install failed — re-run to retry"
        fi
    fi
}

# Every script in bin/ goes to ~/.local/bin. Scripts deployed by an earlier
# run but since removed from the repo are deleted, so old machines converge.
deploy_helper_scripts() {
    echo ""
    echo "🔧 Installing helper scripts to ~/.local/bin..."
    local manifest="$ENV_SETUP_STATE/bin.manifest" script name
    local current=()
    for script in "$DEV_DIR"/bin/*; do
        name="$(basename "$script")"
        current+=("$name")
        deploy_file "$script" "$HOME/.local/bin/$name" 755
    done
    if [ -f "$manifest" ]; then
        while IFS= read -r name; do
            [ -z "$name" ] && continue
            printf '%s\n' "${current[@]}" | grep -qxF "$name" && continue
            if [ -e "$HOME/.local/bin/$name" ]; then
                rm -f "$HOME/.local/bin/$name"
                echo "   🗑️  Removed ~/.local/bin/$name (no longer in the repo)"
            fi
        done < "$manifest"
    fi
    mkdir -p "$ENV_SETUP_STATE"
    printf '%s\n' "${current[@]}" > "$manifest"
}

# A running tmux server keeps the config it started with, so reload it.
deploy_tmux() {
    echo ""
    echo "🖥️  Installing tmux config..."
    deploy_file "$DEV_DIR/tmux.conf" "$HOME/.tmux.conf"
    if [ "$DEPLOY_CHANGED" = 1 ] && tmux info &>/dev/null; then
        tmux source-file "$HOME/.tmux.conf" && "$HOME/.local/bin/tmux-profile-style" || true
        echo "   🔄 Reloaded the running tmux server"
    fi
}

# The block lives in its own file; ~/.zshrc only gets one source line.
# An older inline copy of the block in ~/.zshrc is cut out and replaced by
# that line, so nothing is defined twice.
deploy_zsh() {
    echo ""
    echo "🐚 Zsh: login shell, Oh My Zsh, base config..."
    set_login_shell_zsh
    install_oh_my_zsh
    deploy_zsh_base

    echo ""
    echo "🐚 Installing zsh dev-profiles block..."
    deploy_file "$DEV_DIR/dev-profiles.zsh" "$ZSH_BLOCK"

    touch ~/.zshrc
    if grep -q '^# dev profiles: work / personal' ~/.zshrc; then
        backup_file ~/.zshrc
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
        backup_file ~/.zshrc
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
# local file has (theme, autoMode, modelSettings, ...) are kept. A copy of what
# was deployed is kept in ~/.local/share/env-setup, so a key the repo has since
# dropped (an old plugin, a hook) is removed instead of lingering forever.
deploy_claude_settings() {
    echo ""
    echo "⚙️  Configuring Claude Code settings..."
    local node_bin rendered cfg target merged last
    node_bin="$(command -v node || echo node)"
    rendered="$(mktemp)"
    sed -e "s#__HOME__#$HOME#g" -e "s#__NODE__#$node_bin#g" "$DEV_DIR/claude-settings.json" > "$rendered"

    for cfg in "$HOME/.claude" "$HOME/.claude-personal"; do
        target="$cfg/settings.json"
        last="$ENV_SETUP_STATE/claude-settings$(basename "$cfg").json"
        mkdir -p "$cfg" "$ENV_SETUP_STATE"
        if [ ! -f "$target" ]; then
            cp "$rendered" "$target"
            cp "$rendered" "$last"
            echo "   ✅ ${target/#$HOME/\~} created"
            continue
        fi
        [ -f "$last" ] || echo '{}' > "$last"
        merged="$(mktemp)"
        jq -s '
          .[0] as $cur | .[1] as $last | .[2] as $new
          | [ $last | paths
              | select(. as $p | ($new | try getpath($p) catch null) == null) ] as $dropped
          | ($cur | delpaths($dropped)) * $new
        ' "$target" "$last" "$rendered" > "$merged"
        if cmp -s <(jq -S . "$target") <(jq -S . "$merged"); then
            echo "   ✅ ${target/#$HOME/\~} up to date"
            rm -f "$merged"
        else
            backup_file "$target"
            mv "$merged" "$target"
            echo "   ✅ ${target/#$HOME/\~} updated (backup: settings.json.bak.$STAMP)"
        fi
        cp "$rendered" "$last"
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
