# GitHub authentication

GitHub CLI authentication is provided by the 1Password shell plugin. Before reporting that `gh` is logged out, run `op plugin run -- gh ...` with normal system permissions outside a restricted sandbox. Do not ask me to run `gh auth login` or persist the token locally.
