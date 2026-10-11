# Daily remote cask updates

The workflow runs on a GitHub-hosted macOS runner at 3:00 a.m. America/New_York,
including daylight saving time. It reads casks from `dot_Brewfile`; it does not
install the full Brewfile or use the developer's Mac-local tap.

Before activation, add a repository Actions secret named `HOMEBREW_BUMP_TOKEN`.
It must authenticate as `dgitman`, read public Homebrew metadata, push branches
to `dgitman/homebrew-cask`, and create pull requests in
`Homebrew/homebrew-cask`. The automatic `GITHUB_TOKEN` is scoped to this
repository and cannot perform those cross-repository writes. Use an appropriate
GitHub personal access token or GitHub App credential, stored only as a secret;
never commit it. The existing fork must be available.

Merge the workflow, then run **Daily cask updates** manually from Actions and
verify its result before replacing the local Codex automation. No migration is
complete until that remote test succeeds.

The job uses `brew bump --cask <cask>` for upstream detection, then
`brew bump-cask-pr --write-only` to prepare the update. It inserts the required
audit, style, install and uninstall checks before pushing the exact tested diff.
This preserves Homebrew's deterministic bump logic while providing validation
that a bare `brew bump --open-pr` would not perform.

The workflow conservatively skips third-party taps, complex architecture
versions, existing PRs, and casks with closed unmerged PR history. Their summaries
identify where contributor review is needed. It only accepts changes to version,
checksum and URL lines; zap paths are unchanged.

At most one automated draft is created, and an existing open PR by dgitman blocks
further submissions. Drafts require contributor review of the version, diff and
zap paths before they are marked ready. No claim of personal review is generated,
and no maintainer replies are automated. A draft includes disclosure that Codex
assisted with the automation and that validation ran automatically.

Failures appear in Actions, and results appear in the run summary. GitHub's
notification settings control workflow failure notifications. Scheduled jobs
may start later than the scheduled time; public-repository schedules may be
disabled after 60 days without repository activity.

Validation performed during preparation: Python syntax compilation and six
offline tests covering duplicate, architecture and release-cooldown handling,
install/uninstall failures, and draft submission ordering. Live remote execution
and actual cask installations remain to be verified after credentials are set.
