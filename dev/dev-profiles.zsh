# ═══════════════════════════════════════════════════════════════════════════
# dev profiles: work / personal        (managed block — edit as one unit)
# Source of truth: env-setup/dev/dev-profiles.zsh. Edit it there and re-run
# dev/install-{linux,mac}.sh; edits made here are overwritten.
# ═══════════════════════════════════════════════════════════════════════════

# Non-login shells (e.g. `ssh host zsh -ic dev-work`) skip /etc/profile, so LANG
# is unset and tmux attaches without UTF-8, rendering » and emoji as "_".
export LANG="${LANG:-en_US.UTF-8}"

export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
export BUN_INSTALL="$HOME/.bun"
[ -d "$BUN_INSTALL/bin" ] && export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# ── 1. tmux passes DEV_PROFILE; every shell derives the rest from it ────────
# work     -> default config dir (~/.claude)
# personal -> ~/.claude-personal
if [[ -z "${DEV_PROFILE:-}" && -n "${TMUX:-}" ]]; then
  _dev_profile="$(tmux show-environment DEV_PROFILE 2>/dev/null)"
  [[ "$_dev_profile" == DEV_PROFILE=* ]] && export DEV_PROFILE="${_dev_profile#DEV_PROFILE=}"
  unset _dev_profile
fi
case "${DEV_PROFILE:-}" in
  personal) export CLAUDE_CONFIG_DIR="$HOME/.claude-personal" ;;
  work)     unset CLAUDE_CONFIG_DIR ;;
esac

# No browser on a Linux box reached over SSH: print login URLs instead of
# opening them. Skipped on macOS, where the laptop has a real browser.
[[ "$OSTYPE" != darwin* && -x "$HOME/.local/bin/dev-browser" ]] && export BROWSER="$HOME/.local/bin/dev-browser"

# ── 2. Folder guard: which account belongs under which workspace ────────────
# Returns 1 on a mismatch. revoco/ is deliberately unguarded.
_dev_folder_guard() {
  emulate -L zsh
  local want="$1"
  case "$PWD" in
    "$HOME/workspaces/personal"|"$HOME/workspaces/personal"/*)
      [[ "$want" == personal ]] || return 1 ;;
    "$HOME/workspaces/magicdoor"|"$HOME/workspaces/magicdoor"/*)
      [[ "$want" == work ]] || return 1 ;;
  esac
  return 0
}

# ── 3. Claude wrappers: strip ANTHROPIC_API_KEY so the Max plan is billed ───
_claude_launch() {
  emulate -L zsh
  local profile="$1"; shift
  if ! _dev_folder_guard "$profile"; then
    print -u2 "⚠️  Launching the ${profile:u} account inside ${PWD/#$HOME/~}"
    if ! read -q "?   Continue? [y/N] "; then print -u2 "\n   aborted."; return 1; fi
    print
  fi
  # env(1) requires every -u flag BEFORE any VAR=value assignment.
  local -a unset_flags assigns
  unset_flags=(-u ANTHROPIC_API_KEY)
  assigns=("DEV_PROFILE=$profile")
  if [[ "$profile" == personal ]]; then
    assigns+=("CLAUDE_CONFIG_DIR=$HOME/.claude-personal")
  else
    unset_flags+=(-u CLAUDE_CONFIG_DIR)
  fi
  # env(1) looks claude up on PATH, so this never recurses into the function.
  command env "${unset_flags[@]}" "${assigns[@]}" claude --dangerously-skip-permissions "$@"
}
claude() {
  if [[ "${DEV_PROFILE:-}" != (work|personal) ]]; then
    print -u2 "✗ DEV_PROFILE is '${DEV_PROFILE:-<unset>}' — run claude-work or claude-personal."
    return 1
  fi
  _claude_launch "$DEV_PROFILE" "$@"
}
claude-work()     { _claude_launch work "$@"; }
claude-personal() { _claude_launch personal "$@"; }

# ── 4. dev-work / dev-personal: fixed tmux sessions ─────────────────────────
_dev_session() {
  emulate -L zsh
  local profile="$1" session="$2" dir="$3"
  if ! tmux has-session -t "=$session" 2>/dev/null; then
    [[ -d "$dir" ]] || { print -u2 "✗ $dir does not exist"; return 1; }
    tmux new-session -d -s "$session" -c "$dir" -e "DEV_PROFILE=$profile" || return 1
  fi
  tmux set-environment -t "=$session" DEV_PROFILE "$profile"
  # Colours live in one place: ~/.local/bin/tmux-profile-style. Re-applied on
  # every call so an older session picks up a changed palette.
  tmux-profile-style "$session"
  if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$session"
  else
    tmux attach-session -t "$session"
  fi
}
dev-work()     { _dev_session work     work     "$HOME/workspaces/magicdoor"; }
dev-personal() { _dev_session personal personal "$HOME/workspaces/personal"; }

alias dev-status='echo "DEV_PROFILE=${DEV_PROFILE:-<unset>}  CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR:-<default ~/.claude>}"; claude-profile-badge'

# ── 5. gwt: git worktree wrapper (~/.local/bin/gwt) ─────────────────────────
# The script runs as a child process, so it cannot change this shell's
# directory. After a successful `gwt add` it writes the worktree path to
# ~/.cache/gwt-last-path and this function cds there.
unalias gwt 2>/dev/null
gwt() {
  command gwt "$@"
  local rc=$?
  if [[ $rc -eq 0 && ( "${1-}" == "a" || "${1-}" == "add" ) ]]; then
    local p
    p=$(cat "$HOME/.cache/gwt-last-path" 2>/dev/null)
    [[ -n "$p" && -d "$p" ]] && cd "$p"
  fi
  return $rc
}
