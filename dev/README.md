# Dev profiles — work / personal Claude Code in tmux

Two fixed tmux sessions, each bound to its own Claude Code account. First built
on Batgirl (CachyOS, 192.168.0.3) on 2026-10-06 to mirror the macOS setup over
the VPN; now deployable anywhere from this folder.

## Install

```sh
./dev/install-linux.sh    # Arch or Debian/Ubuntu (also run by install-arch.sh / install-server.sh)
./dev/install-mac.sh      # macOS, needs Homebrew (also run by install-mac.sh)
exec zsh
```

Both install zsh, tmux, jq, node, mosh and Claude Code (native installer,
which updates itself) if missing, then run the
shared steps in `common.sh`. Re-run either one after pulling to update: the
machine converges to the repo, whatever older version it had. Every changed
file is backed up as `*.bak.<epoch>` before it is replaced.

- **zsh:** zsh becomes the login shell and Oh My Zsh is installed. The repo's
  config lives in `~/.config/zsh/base.zsh` (first line of `~/.zshrc`) and
  `~/.config/zsh/dev-profiles.zsh`; `~/.zshrc` only gets their `source` lines,
  so lines other tools add to it are kept. Copies of those lines that older
  installers wrote inline are removed.
- **`settings.json`** (both profiles): keys defined in `claude-settings.json`
  are set to the repo value; keys only you have (theme, autoMode, ...) are
  kept. A key that an earlier run deployed and the repo has since dropped (a
  plugin, a hook) is removed.
- **`bin/`:** a script removed from the repo is removed from `~/.local/bin`.
- **tmux:** a running tmux server is reloaded when `tmux.conf` changes.

What the last run deployed is kept in `~/.local/share/env-setup/`, which is
how dropped keys and scripts are found.

## Secrets

API keys, MagicDoor credentials and the SSH key are in the private
[env-setup-secrets](https://github.com/KRSogaard/env-setup-secrets) repo. Clone
it next to this one and the installers run its `install.sh`: `~/.zshrc` sources
`secrets.zsh` straight from that checkout (so edits apply to new shells) and
the SSH key is copied to `~/.ssh`. Without it, the step is skipped.

## Connecting from the laptop

```sh
mosh kasper@192.168.0.3      # preferred: survives VPN drops and lid close
ssh  kasper@192.168.0.3      # fallback; needed for port forwards and scp
dev-work                     # or dev-personal
```

## The two commands

| Command        | tmux session | Starts in                | Claude config dir     | Bar            |
|----------------|--------------|--------------------------|-----------------------|----------------|
| `dev-work`     | `work`       | `~/workspaces/magicdoor` | `~/.claude`           | blue WORK      |
| `dev-personal` | `personal`   | `~/workspaces/personal`  | `~/.claude-personal`  | green PERSONAL |

Sessions are fixed-name, so disconnecting and re-running lands you back in the
same windows. Run from inside tmux it switches session instead of nesting.

## How the account gets picked

1. `dev-*` creates the tmux session with `DEV_PROFILE=work|personal`.
2. `~/.zshrc` reads `DEV_PROFILE` and sets `CLAUDE_CONFIG_DIR` (personal) or
   unsets it (work -> default `~/.claude`).
3. Each config dir holds its own settings, plugins, MCP servers and login.

Unlike macOS there is no Keychain: credentials live in `.credentials.json`
*inside* each config dir, so the split is cleaner here.

## Files

| Repo file                    | Deployed to                          | Purpose                                              |
|------------------------------|--------------------------------------|------------------------------------------------------|
| `install-linux.sh` / `install-mac.sh` | —                           | entry points: platform packages, then `common.sh`    |
| `common.sh`                  | —                                    | shared, idempotent deploy steps                      |
| `../lib/common.sh`           | —                                    | helpers shared with the top-level installers         |
| `../shell/base.zsh`          | `~/.config/zsh/base.zsh`             | Oh My Zsh, PATH, aliases (sourced first from `~/.zshrc`) |
| `dev-profiles.zsh`           | `~/.config/zsh/dev-profiles.zsh`     | profile derivation, `claude` wrappers, `dev-*` (sourced from `~/.zshrc`) |
| `tmux.conf`                  | `~/.tmux.conf`                       | extended keys, true colour, profile-coloured bar     |
| `claude-settings.json`       | `~/.claude/` + `~/.claude-personal/` `settings.json` | bypass permissions, model/effort, fullscreen TUI, bell hooks, claude-hud status line, plugins |
| `bin/tmux-profile-style`     | `~/.local/bin/`                      | colours a session by name (session-created hook)     |
| `bin/claude-tmux-bell`       | `~/.local/bin/`                      | Stop/Notification/PermissionRequest hook, rings inactive window tabs |
| `bin/claude-profile-badge`   | `~/.local/bin/`                      | `🏢 WORK` / `🏠 PERSONAL` from the real login        |
| `bin/dev-browser`            | `~/.local/bin/`                      | `$BROWSER` on Linux: prints login URLs instead of opening |
| `bin/gwt`                    | `~/.local/bin/`                      | git worktree wrapper (see below); its `cd` wrapper is in `dev-profiles.zsh` |

## gwt — git worktree wrapper

Moved here from the `personal-tools` repo. Requires `git` and `bash`.

| Command | What it does |
| --- | --- |
| `gwt ls` | List all worktrees. |
| `gwt add <branch>` (or `gwt a`) | Create a worktree for the branch and `cd` into it. |
| `gwt remove` (or `gwt r`) | Pick a worktree from a list and remove it. |
| `gwt prune` (or `gwt p`) | Remove every worktree except the main one. |

Worktrees go in a sibling folder `<repo>-wts`: `~/code/backend` gets them under
`~/code/backend-wts/`. Slashes in a branch name become dashes in the folder
name. `gwt add` uses the local branch if one exists, otherwise tracks it from
`origin`, otherwise creates it from `origin`'s default branch.

A script cannot change its caller's directory, so `gwt add` writes the path to
`~/.cache/gwt-last-path` and the `gwt` function in `dev-profiles.zsh` cds there.
The installer replaces the old `~/.local/bin/gwt` symlink with a copy and
drops the personal-tools `source` line from `~/.zshrc`.

## Claude settings shared by both profiles

`claude-settings.json` sets: `model: opus[1m]`, `effortLevel: xhigh`,
`tui: fullscreen`, input-needed and agent push notifications, the
`claude-tmux-bell` hooks, and the claude-hud status line (it picks the newest
installed claude-hud from the active config dir and runs it with `node`).

Plugins enabled in both, with their marketplaces registered in
`extraKnownMarketplaces` so a fresh box can install them:

| Plugin | Marketplace (GitHub) |
|---|---|
| `typescript-lsp` | `claude-plugins-official` |
| `claude-hud` | `jarrodwatts/claude-hud` |
| `savvy-progress` | `JohnnyVizz/claude-kit` |
| `filetree` | `data-goblin/claude-code-filetree` |
| `reflect-mod` | `BayramAnnakov/claude-reflect` |
| `skins` | `hellosverre/claude-skins` |
| `cc-plugin-you-should-know` | builtin |

## Safety nets

- **No permission prompts.** The wrappers pass `--dangerously-skip-permissions`
  and both settings files use `defaultMode: bypassPermissions`.
- **API key stripped.** `secrets.zsh` no longer exports `ANTHROPIC_API_KEY`
  (only `with-anthropic-key <cmd>` passes it on). As a second guard, the
  `claude` / `claude-work` / `claude-personal` wrappers launch via
  `env -u ANTHROPIC_API_KEY`, so the Max subscription is always billed.
- **Folder guard.** Launching the work account under `~/workspaces/personal`
  (or the reverse) warns and asks first. `revoco/` is deliberately unguarded.
- **Coloured bar.** Blue WORK / green PERSONAL, incl. pane borders and messages.
- **Badge** reports the account actually logged in, not the claimed profile.
- **Bell** rings only *inactive* tmux windows.

## Gotchas found and worked around

- `tmux set-option -t "=name"` is rejected on tmux 3.7c ("no such session")
  although `has-session -t "=name"` accepts it. `set-option` uses plain names.
- `%hidden` tmux variables do not expand recursively, so palette refs nested
  inside another `%hidden` must be literal hex.
- `env` requires every `-u` flag *before* any `VAR=value` assignment.
- Style options (`pane-active-border-style`, `message-style`) are not reliably
  format-expanded, so they are pinned per session rather than conditionally.
- In zsh, an unquoted `=work` is command-path expansion. Always quote tmux targets.
- Non-login shells (`ssh host zsh -ic dev-work`) skip `/etc/profile`, so `LANG`
  is unset and tmux renders `»` and emoji as `_`. `dev-profiles.zsh` defaults
  `LANG` to `en_US.UTF-8`.

## Shift+Enter over SSH

The cause was tmux flattening Shift+Enter to Enter. Fixed server-side with
`extended-keys on`, `terminal-features *:extkeys`, `extended-keys-format csi-u`
and `escape-time 0`. The laptop terminal must also send the sequence — in
Claude Code run `/terminal-setup` locally if it still sends on Shift+Enter.

## Decisions worth revisiting

- **No Catppuccin tmux plugin.** Its status bar would clobber the
  profile-coloured bar, which is the safety signal. The config uses the mocha
  palette inline instead.
- **Theme not set** in either settings.json: the docs do not enumerate valid
  theme names, so set it via `/config` rather than guessing.

## Not carried over from the Mac

| Thing | Status |
|---|---|
| Work login | needs one `/login` as kasper@magicdoor.com |
| Work auto-mode MagicDoor rules | cleared; regenerate on this box |
| CLAUDE.md (Batgirl persona, work rules) | copy from the Mac |
| Rider MCP | points at 127.0.0.1 on the Mac; will not reach here |
| Grafana MCP | `mcp-grafana` is a Mac binary; needs a Linux build + token |
| catppuccin + csharp-lsp Claude plugins | not installed here |
| `pbcopy` | tmux.conf picks `pbcopy` or `wl-copy` by OS |
| Claude Desktop split | macOS only, not applicable |

Plugin versions match in **both** profiles here (as of 2026-10-09): claude-hud 0.4.1,
savvy-progress 1.2.0, filetree 0.2.24, reflect-mod 3.3.0, skins 0.1.2,
typescript-lsp 1.0.0. (The Mac had claude-hud 0.5.0 vs 0.10.0 drift.)
