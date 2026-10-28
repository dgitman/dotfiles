# GitHub authentication

GitHub CLI authentication uses `gh auth login`, with the token in the macOS keychain. If `gh` reports being logged out, first rerun it with normal system permissions outside a restricted sandbox (the sandbox can block keychain access). If it is still logged out, ask me to run `gh auth login`; do not run it yourself.

# Git workflow

When a change is finished and its tests pass, commit it, merge it to `main`, and push `main` to `origin` without asking me first. This is standing approval.

- Fast-forward merges only. If `main` has diverged or a push is rejected, stop and tell me. Never force-push.
- Run the project's tests before merging. If they fail, don't merge or push; report the failure.
- Delete the local feature branch after a successful merge and push.
- Never commit secrets, `.env` files, or tokens.
- This approval covers my own repos under `~/Developer` and `~/.local/share/chezmoi`. For any other repo, ask first.
