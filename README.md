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
- `dot_config/gh/private_hosts.yml` — GitHub CLI config (`git_protocol = ssh`)
- `dot_config/private_op/private_plugins/private_gh.json.tmpl` — 1Password
  shell plugin metadata for `gh` (references a vault item, not a raw token)
- `dot_codex/private_config.toml.tmpl` — Codex CLI/desktop config (plugins,
  trusted project paths, MCP servers)
- `dot_claude/private_settings.json` — Claude Code settings
- `dot_warp/settings.toml` — Warp terminal settings
- `private_Library/.../private_claude_desktop_config.json.tmpl` — Claude
  Desktop MCP servers and preferences
- `run_onchange_before_install-packages-darwin.sh.tmpl` — runs
  Homebrew Bundle from the tracked source whenever `dot_Brewfile` changes;
  installation failures stop the apply and are retried on the next apply

## Secrets

No raw secrets are committed. Credentials are referenced indirectly via:

- The [1Password CLI shell plugin](https://developer.1password.com/docs/cli/shell-plugins/)
  (`~/.config/op/plugins.sh`), which wraps commands like `gh` to inject
  tokens (`GH_TOKEN`) from 1Password at invocation time.
- `onepasswordRead "op://…"` in MCP config templates, resolved by chezmoi
  when rendering/applying the config. The generated private files contain the
  credentials; MCP servers start directly without `op run` or `op read`.

Unlock 1Password and enable its CLI integration before applying these templates.
Run `chezmoi apply` again after rotating a credential, then restart the affected
MCP client. This retrieves existing secrets; it does not generate new passwords.
JSON encoding preserves quotes, backslashes, and newlines in credential values.
Avoid sharing rendered configs or secret-bearing `chezmoi diff` output.

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
run the `run_onchange_*` scripts, including package installation from
`dot_Brewfile`. The package hook uses a temporary copy of the tracked Brewfile
because it runs before the home-directory files are updated.

## Automatic Brewfile snapshots

`~/.local/bin/brewfile-sync` refreshes `~/.Brewfile`, re-adds it to chezmoi,
and commits **only `dot_Brewfile`** when its content changes. Run `brewfile-sync`
from your shell to trigger it manually. After a successful commit it pushes the current
branch to its configured upstream. Other staged and unstaged changes are
preserved; merge/rebase conflicts stop the run. Automation commits are unsigned
and bypass Git hooks so they cannot prompt for credentials or include additional
files. Other Git commands retain the normal signing/hooks.

The `net.gitman.brewfile-sync` LaunchAgent runs at login and every hour while
macOS is awake. Logs: `~/Library/Logs/brewfile-sync.log`. The chezmoi
`run_onchange_after_brewfile-sync-agent.sh.tmpl` hook loads/reloads the agent
when its script or plist changes. A normal `chezmoi apply` installs it on a new
Mac after the package-setup step. macOS may ask to allow background activity.

The snapshot includes supported Homebrew formulae/casks/taps/trust settings,
Mac App Store apps, VS Code extensions, and global npm packages visible to the
scheduled PATH. Project-local dependencies and globals in other Node-version
prefixes are not included. GUI installations are captured on the next run.

Local paths under the current home directory are normalized to `Dir.home` or
`File.join(Dir.home, …)` before comparison and commit. Homebrew can dump absolute
paths again on every run without putting a machine-specific home path back into
the tracked Brewfile. Remote URLs and paths outside the home directory are kept.

Package collection is checked before replacing the current snapshot. A failed
command, empty snapshot, or missing CLI for an already-tracked source stops the
run rather than dropping that inventory. Logs explain failures. The script uses
a lock to prevent overlap and a temporary file before replacing the Brewfile.

```sh
brewfile-sync                              # refresh, commit, and push now
launchctl print gui/$(id -u)/net.gitman.brewfile-sync
python3 tests/test_brewfile_sync.py         # isolated mock-command tests on macOS
```

Source files: `dot_local/bin/executable_brewfile-sync`,
`private_Library/LaunchAgents/net.gitman.brewfile-sync.plist.tmpl`, and the
setup hook above. The job does not install/uninstall packages. A later full
`chezmoi apply` can still run the repository's existing package-install hook.

## Additional restore files

`dot_local/bin/executable_vcf_embedder.py` preserves the personal vCard photo
embedding utility as `~/.local/bin/vcf_embedder.py`. It rewrites vCards in the
selected directory and creates backups of changed files.
`private_dot_aws/config` restores the default AWS region; AWS credentials are
not tracked.

`pipx-packages.json` records the installed pipx applications separately from the
Brewfile. The current inventory is `ray[default]` version `2.58.0`, with no
injected packages or dependency applications exposed. After Homebrew setup,
restore it with:

```sh
pipx install 'ray[default]==2.58.0'
```

This recreates the `ray`, `serve`, and `tune` commands. Update the inventory when
changing pipx packages; the hourly Brewfile snapshot does not collect them.

## Restoring personal background jobs

chezmoi preserves portable LaunchAgent templates for Remtasks and the hourly
and daily Messages Sync jobs. Applying their files does not load or restart
these jobs. Their application code, Python environments, permissions, and log
directories must be restored separately before loading them.

For Remtasks, restore `~/Developer/dgitman/apple-reminders-google-tasks-sync`,
then follow that project's README to create its signing identity and run
`scripts/install.sh`. Apply the tracked Remtasks config after installation,
grant Full Disk Access to the installed binary, and run `remtasks doctor`.
The project command `remtasks install-agent` loads its daemon; the tracked
plist preserves the current five-minute interval.

For Messages Sync, restore `~/Developer/dgitman/gitman-messages-sync`, set up its
Python environment following the project README, apply its tracked config,
and grant Full Disk Access to its launchers. Confirm the Mac timezone is
`America/New_York` and complete the project's controlled write checks before
loading the jobs. The tracked plists retain the current write gates: hourly
incremental sync and reconciliation daily at 2 a.m. local time.

Once those prerequisites are complete, the Messages Sync jobs can be loaded
with:

```sh
mkdir -p "$HOME/Library/Logs/GitmanMessagesSync"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.davidgitman.gitman-messages-sync.incremental.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.davidgitman.gitman-messages-sync.reconcile.plist"
```

The Contacts photo repair agent remains owned by its separate helper under
`~/Documents/Codex/contacts-hourly-helper`; it is not included in this restore.
