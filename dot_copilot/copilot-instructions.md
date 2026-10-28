# GitHub authentication

GitHub CLI authentication uses `gh auth login`, with the token in the macOS keychain. If `gh` reports being logged out, first rerun it with normal system permissions outside a restricted sandbox (the sandbox can block keychain access). If it is still logged out, ask me to run `gh auth login`; do not run it yourself.
