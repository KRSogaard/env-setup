# KEYS: API keys, MagicDoor credentials (private repo, see env-setup-secrets)
[ -f "$HOME/workspaces/personal/env-setup-secrets/secrets.zsh" ] && source "$HOME/workspaces/personal/env-setup-secrets/secrets.zsh"

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="af-magic"
plugins=(git)
source $ZSH/oh-my-zsh.sh
eval "$(/opt/homebrew/bin/brew shellenv)"

export PATH="$PATH:/Users/kasper/.local/bin/"
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
export PATH=/Users/kasper/.opencode/bin:$PATH
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export PATH="$PATH:/Users/kasper/.dotnet/tools"

alias ds="dotnet script"
alias de="dotnet ef"

clear
fastfetch