# GitHub authentication

GitHub CLI authentication is provided by the 1Password shell plugin. Before reporting that `gh` is logged out, run `op plugin run -- gh ...` with normal system permissions outside a restricted sandbox. Do not ask me to run `gh auth login` or persist the token locally.

# Git workflow

When a change is finished and its tests pass, commit it, merge it to `main`, and push `main` to `origin` without asking me first. This is standing approval.

- Fast-forward merges only. If `main` has diverged or a push is rejected, stop and tell me. Never force-push.
- Run the project's tests before merging. If they fail, don't merge or push; report the failure.
- Delete the local feature branch after a successful merge and push.
- Never commit secrets, `.env` files, or tokens.
- This approval covers my own repos under `~/Developer` and `~/.local/share/chezmoi`. For any other repo, ask first.
