# dotfiles

Personal macOS configuration managed with [chezmoi](https://www.chezmoi.io/).

## Structure

Standard chezmoi naming conventions apply:

- `dot_*` → `~/.*` (e.g. `dot_zshrc` → `~/.zshrc`)
- `private_*` → written with `0600` permissions (used for files containing
  credential metadata or tokens, e.g. `private_config.toml.tmpl`)
- `*.tmpl` → Go templates, rendered with values like `.chezmoi.homeDir`
- `run_onchange_*` → scripts that re-run automatically when their rendered
  content changes (see below)

Notable tracked files:

- `dot_zshrc` — shell config, aliases, Homebrew integration
- `dot_Brewfile` — Homebrew formulae, casks, VS Code extensions, npm globals
- `dot_config/private_gh/private_hosts.yml` — GitHub CLI config (`git_protocol = ssh`)
- `dot_config/private_op/private_plugins/private_gh.json.tmpl` — 1Password
  shell plugin metadata for `gh` (references a vault item, not a raw token)
- `dot_codex/private_config.toml.tmpl` — Codex CLI/desktop config (plugins,
  trusted project paths, MCP servers)
- `dot_claude/private_settings.json` — Claude Code settings
- `dot_warp/settings.toml` — Warp terminal settings
- `private_Library/.../private_claude_desktop_config.json.tmpl` — Claude
  Desktop MCP servers and preferences
- `run_onchange_before_install-packages-darwin.sh.tmpl` — runs
  `brew bundle --global` whenever `dot_Brewfile` changes
- `run_onchange_after_macos-update.sh.tmpl` — records the current macOS
  build version

## Secrets

No raw secrets are committed. Credentials are referenced indirectly via:

- The [1Password CLI shell plugin](https://developer.1password.com/docs/cli/shell-plugins/)
  (`~/.config/op/plugins.sh`), which wraps commands like `gh` to inject
  tokens (`GH_TOKEN`) from 1Password at invocation time.
- `op://` references inside MCP server / Codex configs, resolved at
  runtime by `op run`.

## GitHub CLI auth

- Single account (`dgitman`), authenticated via the 1Password `gh` plugin
  (`GH_TOKEN` env var), scoped with broad repo/org/workflow permissions.
- `git_protocol` is set to `ssh` — both `gh` and all repos under
  `~/Developer` use SSH remotes (`git@github.com:...`), not HTTPS.

## Common commands

```zsh
chezmoi diff              # preview pending changes before applying
chezmoi apply             # apply tracked config to the live system
chezmoi re-add            # pull local edits back into the source state
                           # (skipped automatically for .tmpl files —
                           #  those must be edited by hand)
chezmoi status             # show pending drift between source/live/last-applied
```

## Health check

Quick sanity check after making changes or setting up a new machine:

```zsh
chezmoi status                          # should be empty
chezmoi doctor                          # no errors (info-level only)
git -C ~/.local/share/chezmoi status    # clean, in sync with origin/main
gh auth status                          # authenticated, protocol = ssh
brew doctor                             # only expected Tier-2/pre-release notes
```

Known benign `brew doctor` warnings on this machine:

- `composio` flagged as having "no formulae" — false positive; it's
  installed from the third-party `composio-temp/tap`, not Homebrew core.
- macOS pre-release version warning — expected when running a beta OS.

## Setup on a new machine

```zsh
chezmoi init --apply git@github.com:dgitman/dotfiles.git
```

This will clone the repo, render templates, write dotfiles into place, and
run the `run_onchange_*` scripts (including `brew bundle --global`, which
installs everything listed in `dot_Brewfile`).

## Automatic Brewfile snapshots

`~/.local/bin/brewfile-sync` refreshes `~/.Brewfile`, re-adds it to chezmoi,
and commits **only `dot_Brewfile`** when its content changes. `brewsync` is the
shell alias for the same script. It never pushes. Other staged and unstaged
changes are preserved; merge/rebase conflicts stop the run. Automation commits
are unsigned and bypass Git hooks so they cannot prompt for credentials or
include additional files. Other Git commands retain the normal signing/hooks.

The `net.gitman.brewfile-sync` LaunchAgent runs at login and every hour while
macOS is awake. Logs: `~/Library/Logs/brewfile-sync.log`. The chezmoi
`run_onchange_after_brewfile-sync-agent.sh.tmpl` hook loads/reloads the agent
when its script or plist changes. A normal `chezmoi apply` installs it on a new
Mac after the package-setup step. macOS may ask to allow background activity.

The snapshot includes supported Homebrew formulae/casks/taps/trust settings,
Mac App Store apps, VS Code extensions, and global npm packages visible to the
scheduled PATH. Project-local dependencies and globals in other Node-version
prefixes are not included. GUI installations are captured on the next run.

Package collection is checked before replacing the current snapshot. A failed
command, empty snapshot, or missing CLI for an already-tracked source stops the
run rather than dropping that inventory. Logs explain failures. The script uses
a lock to prevent overlap and a temporary file before replacing the Brewfile.

```sh
brewsync                                   # refresh and commit now
launchctl print gui/$(id -u)/net.gitman.brewfile-sync
python3 tests/test_brewfile_sync.py         # isolated mock-command tests on macOS
```

Source files: `dot_local/bin/executable_brewfile-sync`,
`private_Library/LaunchAgents/net.gitman.brewfile-sync.plist.tmpl`, and the
setup hook above. The job does not install/uninstall packages. A later full
`chezmoi apply` can still run the repository's existing package-install hook.
