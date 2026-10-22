# dotfiles

Personal macOS configuration managed with [chezmoi](https://www.chezmoi.io/).

## Structure

Standard chezmoi naming conventions apply:

- `dot_*` → `~/.*` (e.g. `private_dot_zshrc.tmpl` → `~/.zshrc`)
- `private_*` → written with `0600` permissions (used for files containing
  credential metadata or tokens, e.g. `private_config.toml.tmpl`)
- `*.tmpl` → Go templates, rendered with values like `.chezmoi.homeDir`
- `run_onchange_*` → scripts that re-run automatically when their rendered
  content changes (see below)

Notable tracked files:

- `bootstrap.sh` — one-command new-Mac restore (repo-only, not applied)
- `private_dot_zshrc.tmpl` — shell config, aliases, Homebrew integration
- `dot_Brewfile` — Homebrew formulae, casks, VS Code extensions, npm globals
- `dot_config/gh/private_hosts.yml` — GitHub CLI config (`git_protocol = ssh`)
- `dot_config/private_op/private_plugins/private_gh.json.tmpl` — 1Password
  shell plugin metadata for `gh` (references a vault item, not a raw token)
- `dot_codex/private_config.toml.tmpl` — Codex CLI/desktop config (plugins,
  trusted project paths, MCP servers)
- `dot_claude/private_settings.json` — Claude Code settings
- `dot_copilot/private_settings.json` — Copilot CLI user preferences;
  automatic login/session state in `config.json` is not tracked
- `dot_warp/settings.toml` — Warp terminal settings
- `private_Library/.../private_claude_desktop_config.json.tmpl` — Claude
  Desktop MCP servers and preferences
- `run_onchange_before_install-packages-darwin.sh.tmpl` — runs
  Homebrew Bundle from the tracked source whenever `dot_Brewfile` changes;
  installation failures stop the apply and are retried on the next apply.
  It skips `tap "homebrew/core"` and local-path development taps such as
  `dgitman/cask-local` (a homebrew-cask fork Homebrew rejects as a tap)
- `run_onchange_after_00-initialize-app-preferences.sh.tmpl` — on first
  apply, opens Afterglow, Grok Bot, and Magnet once and quits them so the
  preference hooks below have existing settings to merge into

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

## Privacy check on commits

This repo is public, so `git-hooks/pre-commit` and `git-hooks/commit-msg` refuse
a commit whose added lines, file names, or message contain this Mac's home path
or a personal email address. Write `{{ .chezmoi.homeDir }}` or a 1Password
lookup instead. The hooks look the values up when they run: `$HOME` and the
`personalEmail`, `workEmail`, and `privateValues` chezmoi data. `chezmoi init`
reads that data from 1Password through `.chezmoi.toml.tmpl`, which holds only
item references; to block another value, add its reference to `privateValues`
there and run `chezmoi init`.

`bootstrap.sh` turns the hooks on with `core.hooksPath`. `git commit
--no-verify` skips the check.

## Weekly health check

`~/.local/bin/chezmoi-health` checks that chezmoi is clean and published:
`chezmoi status` is empty, the source repo is committed and matches
`origin/main`, the privacy hooks are on, no tracked file or commit message has
the home path, a private value, or a credential-shaped string, no
`dot_chezmoi.*` file is managed, every managed LaunchAgent's program exists,
and the repo tests pass. It also lists unmanaged dotfiles and `~/.config`
entries that are not on its reviewed list. It prints `OK`, `ISSUE`, or
`REVIEW` per check, never prints private values, and exits 1 on any issue.
1Password must be unlocked.

A Claude scheduled task named "Weekly chezmoi health check" runs it early on
Sunday mornings, fixes what it finds, commits through the privacy hooks, and
pushes `main`. It runs only while the Claude app is open; a missed run starts
on the next launch.

## GitHub CLI auth

- Single account (`dgitman`), authenticated via the 1Password `gh` plugin
  (`GH_TOKEN` env var), scoped with broad repo/org/workflow permissions.
- `git_protocol` is set to `ssh` — both `gh` and all repos under
  `~/Developer` use SSH remotes (`git@github.com:...`), not HTTPS.

## Editor

`.chezmoi.toml.tmpl` sets VS Code (`code`) as the editor for `chezmoi edit`, the
viewer for `chezmoi diff`, and the three-way merge tool for `chezmoi merge`.
After changing that template, run `chezmoi init` to regenerate
`~/.config/chezmoi/chezmoi.toml` (`bootstrap.sh` does this on every run).

## Common commands

```zsh
chezmoi diff              # preview pending changes before applying
chezmoi apply             # apply tracked config to the live system
chezmoi re-add            # pull local edits back into the source state
                           # (skipped automatically for .tmpl files —
                           #  those must be edited by hand)
chezmoi status             # show pending drift between source/live/last-applied
gcloud auth print-access-token >/dev/null && echo ok   # check Google Cloud auth
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

### One-command restore

In the macOS Terminal on a fresh Mac, run:

```zsh
curl -fsSL https://raw.githubusercontent.com/dgitman/dotfiles/main/bootstrap.sh | bash
```

`-f` makes curl fail on an HTTP error instead of piping an error page into
bash. The script reads prompts from the terminal, so password and email
prompts work even though it is piped.

[`bootstrap.sh`](bootstrap.sh) does the following, skipping anything already
done, so it is safe to re-run:

1. Installs Homebrew (which also installs the Xcode Command Line Tools). Expect
   a password prompt and a Command Line Tools download.
2. Installs the 1Password app, the 1Password CLI (`1password-cli`, matching
   `dot_Brewfile`), and chezmoi with Homebrew.
3. Opens 1Password and pauses. Sign in and unlock, then in
   **Settings → Developer** turn on **Integrate with 1Password CLI** and
   **Use the SSH agent**, then press Return. The script then runs
   `op vault list` once so macOS asks whether Terminal may access data from
   other apps right away; click **Allow**. If it still fails, the script opens
   Files & Folders and exits: turn the toggle on, open a **new** Terminal
   window (the setting does not apply to windows already open), and re-run. Without it `op` reports
   "You are not currently signed in" even with the app unlocked. If the prompt
   was missed or denied, go to **System Settings → Privacy & Security → Files &
   Folders → Terminal** and turn on **Data shared by 1Password Launcher and
   affiliated apps**. The toggle appears there after `op` has tried once. If chezmoi later reports that the
   1Password CLI is not signed in, run `eval "$(op signin)"` and re-run the
   bootstrap command in the same terminal.
4. Runs `chezmoi init --apply https://github.com/dgitman/dotfiles.git`. chezmoi
   asks for the personal and work emails, reads secrets from 1Password, writes
   the dotfiles, and runs the `run_onchange_*` hooks, including `brew bundle`
   for everything in `dot_Brewfile` (this takes a while).
5. Switches the chezmoi repo's `origin` to SSH
   (`git@github.com:dgitman/dotfiles.git`) so `brewfile-sync` can push through
   the 1Password SSH agent.
6. Finishes the steps that used to be manual:
   - clones every non-archived repo of `dgitman` and `because-ventures` into
     `~/Developer/<owner>/<repo>` over SSH (existing folders are left alone;
     the dotfiles repo itself is skipped);
   - adds the Brother HL-L2460DW over AirPrint as `Brother_HL_L2460DW` if it is
     on the network;
   - offers to download the After Dark 10th Anniversary disc image from
     archive.org to `~/Downloads`, mounts it, and opens Afterglow for the
     module import (skipped once the image is in `~/Downloads`);
   - runs `chezmoi status` and `chezmoi doctor` and shows only problems.
7. Checks Google Cloud sign-in for the restored gcloud account and offers
   sign-in if needed, showing a login link for your preferred browser (it only
   prints a confirmation when already signed in).
8. Until the Remtasks and Messages Sync agents are loaded, sets them up:
   builds and signs Remtasks (`make-signing-identity.sh` asks for your password
   once), creates the Messages Sync Python environment, opens **Full Disk
   Access** and shows the files to add in Finder, runs `remtasks doctor` and the
   read-only Messages `validate-source` check, then asks before starting each
   sync job. Answer **y** only after stopping that job on the old Mac.

Sign in to the Mac App Store before running it; Magnet is installed from there.

After packages install, the apply opens Afterglow, Grok Bot, and Magnet once in
the background so they create their preferences, then quits them before the
preference hooks run. If macOS asks whether to open an app downloaded from the
internet, click **Open**. If the apply still stops partway, read its message,
fix what it names (usually: open that app once and quit it), then re-run the
bootstrap command or `chezmoi apply`.

Then continue with the [post-rebuild checklist](#post-rebuild-checklist) from
step 4.

### Manual restore

The same steps by hand:

```zsh
# 1. Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

# 2. 1Password, its CLI, and chezmoi
brew install --cask 1password 1password-cli
brew install chezmoi

# 3. Open 1Password, sign in, and enable Settings → Developer →
#    "Integrate with 1Password CLI" and "Use the SSH agent". Then confirm, and
#    allow Terminal to access data from other apps if macOS asks (Privacy &
#    Security → Files & Folders → Terminal → "Data shared by 1Password Launcher
#    and affiliated apps"):
op vault list

# 4. Clone and apply
chezmoi init --apply https://github.com/dgitman/dotfiles.git
chezmoi git -- remote set-url origin git@github.com:dgitman/dotfiles.git
```

`chezmoi init --apply` clones the repo, renders templates, writes dotfiles into
place, and runs the `run_onchange_*` scripts, including package installation
from `dot_Brewfile`. The package hook uses a temporary copy of the tracked
Brewfile because it runs before the home-directory files are updated.

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
`private_dot_aws/config` restores the default AWS region.
`private_dot_aws/private_credentials.tmpl` restores the default AWS access key
and secret access key from the AWS item in 1Password. Git stores only the
references; chezmoi writes `~/.aws/credentials` with private permissions.
Reapply after rotating the keys and never re-add the rendered credentials.

## Restoring personal background jobs

chezmoi preserves portable LaunchAgent templates for Remtasks and the hourly
Messages Sync job. Applying their files does not load or restart
these jobs. Their application code, Python environments, permissions, and log
directories must be restored separately before loading them.

`bootstrap.sh` clones both projects and runs the install, Full Disk Access,
check, and load steps below, asking before it starts either sync job. Full Disk
Access is the one step that always needs your clicks: macOS never prompts for
it. The Messages Sync controlled write tests are not repeated; the queue starts
fresh, and a manual `sync --mode reconcile` run (see the project README)
baselines rows that are already in the Sheet.

For Remtasks, in `~/Developer/dgitman/apple-reminders-google-tasks-sync`,
follow that project's README to create its signing identity and run
`scripts/install.sh`. Apply the tracked Remtasks config after installation,
grant Full Disk Access to the installed binary, and run `remtasks doctor`.
The project command `remtasks install-agent` loads its daemon; the tracked
plist preserves the current five-minute interval.

For Messages Sync, restore `~/Developer/dgitman/gitman-messages-sync`, set up its
Python environment following the project README, apply its tracked config,
and grant Full Disk Access to its launchers. Confirm the Mac timezone is
`America/New_York` and complete the project's controlled write checks before
loading the job. The tracked plist retains the current write gate: hourly
incremental sync. The daily reconcile job was retired on 2026-10-20;
reconciliation is now a manual run.

Once those prerequisites are complete, the Messages Sync job can be loaded
with:

```sh
mkdir -p "$HOME/Library/Logs/GitmanMessagesSync"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.davidgitman.gitman-messages-sync.incremental.plist"
```

The Contacts photo repair agent remains owned by its separate helper under
`~/Documents/Codex/contacts-hourly-helper`; it is not included in this restore.

## Magnet custom layout

`magnet-stage-manager.json` preserves only the Stage Manager horizontal layout,
identified by `C2DE2F7B-A5A5-4555-B11C-93D1AF1A7CC1`. Its restore hook merges
that entry into `horizontalCommands` through macOS's preferences service,
leaving other layouts and preferences unchanged. It preserves the existing
storage type and does nothing if the saved entry already matches.

On a new Mac, the first apply opens Magnet once to initialize its defaults and
quits it. If that times out, open Magnet once, quit it, then run `chezmoi apply`. If a layout change is needed while Magnet is running, the
hook stops with instructions to quit and retry. Edit the tracked JSON manually
to capture later changes to this layout; `chezmoi re-add` does not capture it.

## Google Cloud CLI configuration

`dot_config/private_gcloud` restores the active `default` configuration and its
account, project, and usage-reporting preference. These files contain account
metadata, not authentication tokens. The empty `personal-profile` and
`work-profile` configurations are not tracked. Sign in separately on a new Mac;
tracking the account preference does not restore authentication.

Google Cloud credential databases, access tokens, application-default
credentials, logs, and generated state are excluded from this restore. Review
new settings before re-adding configurations to avoid tracking credentials.

## Post-rebuild checklist

1. Install and unlock 1Password, enable its CLI integration, allow Terminal
   to access 1Password's shared data (Files & Folders), and set up its SSH agent before cloning private repositories or resolving secret references.
   `bootstrap.sh` handles this step and the next.
2. Initialize chezmoi and apply the configuration. For Magnet, open it once and
   quit it before retrying the apply if its restore hook requests that step.
3. Sign in to Google Cloud. `bootstrap.sh` checks this and offers sign-in; to
   do it later, run `gcloud auth login`.
4. Repo clones, the printer, the After Dark download, and the
   `chezmoi status` / `chezmoi doctor` checks are run by `bootstrap.sh`.
   Import the After Dark modules in Afterglow, and complete the personal
   background job prerequisites before loading their agents.
5. Re-run `chezmoi status` and `chezmoi doctor` after any manual changes.

Google Cloud verification discards the access token and never prints it.
A failed verification can also mean a connectivity or account problem; it does
not necessarily mean you are signed out. The bootstrap handles gcloud CLI
login only. If a development project requires Application Default Credentials,
complete its separate `gcloud auth application-default login` setup.
AWS credentials are restored from 1Password by the tracked credentials template.

## Afterglow preferences

`afterglow-preferences.json` preserves the selected After Dark 10th Anniversary
collection and Toaster 2k settings (control values `[25, 1, 80, 0]` and volume
`1`). Its restore hook merges saved module settings with existing module
settings through macOS's preferences service and changes only those settings
and the selected collection. Other preferences, window positions, updater
state, generated catalogs, and caches are unmanaged.

The first apply opens Afterglow once to initialize its preferences and quits
it; if that times out, open and quit it manually and run `chezmoi apply`. `bootstrap.sh` offers to download the After Dark
10th Anniversary disc image ([archive.org](https://archive.org/details/Macintosh_Garden_Apps_Collection_A))
to `~/Downloads`, mounts it, and opens Afterglow; use Afterglow's import
workflow to restore Hall of Fame and Toaster 2k. The module binaries and
resources are not stored in this dotfiles repository.
If Afterglow is running and settings need to change, the hook asks you to quit
and retry. Edit the tracked JSON to preserve later changes; `chezmoi re-add`
does not capture preferences managed by this hook.

## Additional application preferences

- `grok-preferences.json` preserves Grok Bot's update, appearance, network/tool,
  meetings/messages, and custom instruction preferences. Its apply hook merges
  these with existing settings, preserving account scopes, onboarding, and
  migration state. The first apply on a rebuilt machine opens Grok Bot once
  and quits it before applying preferences. Edit the saved JSON to capture future preference changes.
- `private_dot_composio/private_config.json` preserves Composio developer and
  security preferences. Account data and authentication files are not tracked.
- `dot_docker/daemon.json` preserves Docker build-cache garbage collection
  (20 GB) and its experimental-feature setting. On a new Mac Docker reads it on
  first launch; restart Docker Desktop after changing it later.
- `private_dot_cups/lpoptions` restores Brother_HL_L2460DW as the default printer.
  `bootstrap.sh` adds that printer over AirPrint when it is on the network; or
  add it by hand using the same queue name.
- `dot_warp/tab_configs/startup_config.toml.tmpl` restores Warp's agent startup
  tab with a portable home-directory path.

`private_dot_boto` restores gsutil preferences from `~/.boto`. Its credential
sections are empty; authentication is handled separately by Google Cloud CLI.
