# Hourly remote cask updates

The [cask updates workflow](workflows/cask-updates.yml) runs on a GitHub-hosted macOS runner at 17 minutes past each hour.
It reads casks from `dot_Brewfile`; it does not install the full Brewfile or use the developer's Mac-local tap.

Before activation, configure one of these authentication routes.

## Recommended: 1Password service account

1. Create a GitHub personal access token (classic) as dgitman with the
   `public_repo` scope and an expiration. This allows pushing to the public fork
   and contributing PRs to public Homebrew repositories. Fine-grained tokens
   currently do not support contributing to public repositories where the user
   is not a member. No `workflow` scope is needed to change cask files.
2. Store the token in a dedicated custom 1Password vault (not Private, Personal,
   Employee or the default Shared vault). Service accounts cannot access those
   built-in vaults. Use a concealed token field.
3. Create a 1Password service account with only read access to that custom vault.
4. In this repository's Actions secrets, store its service account token as
   `OP_SERVICE_ACCOUNT_TOKEN`.
5. In this repository's Actions variables, set
   `HOMEBREW_BUMP_SECRET_REFERENCE` to the GitHub token field's secret reference.
   Prefer vault/item IDs in that reference. The variable holds a reference,
   not the token value.

The pinned 1Password load-secrets action retrieves the token at runtime and
exports it as `GH_TOKEN` and `HOMEBREW_GITHUB_API_TOKEN`. Its service account
credential is limited to that load step. Values are masked in logs. This uses
the documented vault-item integration, rather than a local environment mount.

## Alternative: direct GitHub Actions secret

Store the GitHub token as the repository Actions secret `HOMEBREW_BUMP_TOKEN`,
and leave `HOMEBREW_BUMP_SECRET_REFERENCE` unset.

Both routes must authenticate as `dgitman`, read public Homebrew metadata, push
branches to `dgitman/homebrew-cask`, and create pull requests in
`Homebrew/homebrew-cask`. The automatic `GITHUB_TOKEN` is scoped to this
repository and cannot perform those cross-repository writes. The existing fork
must be available. Never commit credentials.

References:
- https://www.1password.dev/ci-cd/github-actions
- https://www.1password.dev/service-accounts/get-started
- https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens

Merge the workflow, then run **Hourly cask updates** manually from [Actions](https://github.com/dgitman/dotfiles/actions/workflows/cask-updates.yml) and
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
