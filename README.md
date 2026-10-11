# env-setup

Setup scripts for my machines, plus the work/personal Claude Code profiles.

| Script | For |
|---|---|
| `install-arch.sh` | Arch / CachyOS desktop |
| `install-mac.sh` | macOS (needs nothing pre-installed) |
| `install-server.sh` | Ubuntu/Debian or Arch server reached over SSH |
| `dev/install-linux.sh`, `dev/install-mac.sh` | just the dev profiles (zsh, tmux, Claude Code); also run by the three above. See [dev/README.md](dev/README.md) |

## Re-running is the update

Every script can run any number of times. Running it after `git pull`
brings the machine to the current version, whatever version it had before:

- Packages are installed if missing and upgraded (pacman/paru, brew).
- Config files the repo owns are deployed whole; a file that differs is
  backed up as `<file>.bak.<epoch>` first. `~/.zshrc` is never rewritten:
  it only gets `source` lines for the repo's files.
- Things the repo stops shipping (a helper script, a Claude setting) are
  removed on the next run. `~/.local/share/env-setup/` records what was
  deployed so this works.
- Questions are asked once. Answers are saved in `~/.config/env-setup/` and
  reused (as the default with a terminal, as-is without one). One-off manual
  steps are not asked again after they are done.

Shared helpers live in `lib/common.sh`.

## Security defaults

- **SSH is key-only** (`system/sshd-env-setup.conf`, Arch desktop and
  servers). Skipped while `~/.ssh/authorized_keys` is empty, so it cannot lock
  you out; root may still log in with a key.
- **GitHub auth goes through `gh`**, which keeps the token in the system
  keyring. The plain-text token older runs left in `~/.git-credentials` is
  removed once `gh` is logged in.
- **Docker publishes ports on 127.0.0.1 by default** (Arch). Docker bypasses
  ufw, so `-p 8080:80` would otherwise be open to the network; use
  `-p 0.0.0.0:8080:80` when that is intended.
- **mosh** is installed everywhere and its UDP ports (60000-61000) are open in ufw.

## Secrets

API keys and the SSH key are in a separate private repo, `env-setup-secrets`.
Clone it next to this one and the installers run its `install.sh`; without it
that step is skipped.
