# ═══════════════════════════════════════════════════════════════════════════
# env-setup base zsh config, sourced from the top of ~/.zshrc.
# Source of truth: env-setup/shell/base.zsh. Edit it there and re-run an
# installer; edits made here are overwritten. Machine-local additions belong
# in ~/.zshrc itself, below the source line.
# ═══════════════════════════════════════════════════════════════════════════

# Non-login shells (e.g. `ssh host zsh -ic dev-work`) skip /etc/profile, so LANG
# is unset and tmux attaches without UTF-8, rendering » and emoji as "_".
export LANG="${LANG:-en_US.UTF-8}"

# ── PATH ────────────────────────────────────────────────────────────────────
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
[[ -d /Applications/Docker.app/Contents/Resources/bin ]] && export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
[[ -d /opt/homebrew/opt/libpq/bin ]] && export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export PATH="$PATH:$HOME/.dotnet/tools"

# ── Oh My Zsh ───────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="af-magic"
plugins=(git)
(( $+commands[fzf] )) && plugins+=(fzf)
[[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# Host badge on the prompt line (after af-magic's dashed separator), so a
# Linux box reached over SSH is never mistaken for the local Mac.
if [[ "$OSTYPE" != darwin* ]]; then
  _host_badge=$'\n'"%B%F{213}[%m]%f%b "
  PS1=${PS1/$'\n'/$_host_badge}
  unset _host_badge
fi

# Autosuggestions + syntax highlighting, wherever the distro put them.
for _p in \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
do
  [[ -r "$_p" ]] && source "$_p"
done
unset _p

# ── Aliases ─────────────────────────────────────────────────────────────────
alias ds="dotnet script"
alias de="dotnet ef"
alias sshOpenClaw="ssh kasper@192.168.10.5"
alias sshDesktop="ssh kasper@192.168.0.3"
