# 1Password-backed secrets

This repository should track references to secrets, not raw secret values.

## Setup

Create a local env file from the tracked template:

```sh
mkdir -p ~/.config/op
cp /Users/dgitman/Developer/dotfiles/config/op/env.example ~/.config/op/dotfiles.env
```

Edit `~/.config/op/dotfiles.env` so each variable points at the right 1Password item and field:

```sh
OPENAI_API_KEY=op://Private/OpenAI API Key/credential
GITHUB_TOKEN=op://Private/GitHub Token/credential
```

The local `~/.config/op/dotfiles.env` file is intentionally ignored. It may contain only 1Password references, but keeping it local makes it safe to experiment with item names and vault layout.

## Usage

Run a command with secrets injected:

```sh
/Users/dgitman/Developer/dotfiles/scripts/with-secrets.sh some-command
```

Open a shell with secrets loaded:

```sh
/Users/dgitman/Developer/dotfiles/scripts/with-secrets.sh
```

Use a different env file if needed:

```sh
DOTFILES_OP_ENV=~/.config/op/work.env /Users/dgitman/Developer/dotfiles/scripts/with-secrets.sh some-command
```

## Restoring Local Config Files

Some tools store useful config in credential-bearing files that should not be committed directly. Keep those file contents in 1Password, track only references in a local env file, then restore them when setting up a machine.

From a terminal where `op` is signed in, store supported local credential files in 1Password and update the local references:

```sh
/Users/dgitman/Developer/dotfiles/scripts/store-op-files.sh
```

Create the local file-reference env file from the tracked template:

```sh
cp /Users/dgitman/Developer/dotfiles/config/op/files.example ~/.config/op/dotfiles-files.env
```

Edit `~/.config/op/dotfiles-files.env` so each variable points at the right 1Password item and field:

```sh
GH_HOSTS_YML="op://Private/GitHub CLI hosts.yml/notesPlain"
CODEX_AUTH_JSON="op://Private/Codex auth.json/notesPlain"
```

Then restore any configured files:

```sh
/Users/dgitman/Developer/dotfiles/scripts/restore-op-files.sh
```

Supported restore targets:

- `GH_HOSTS_YML` -> `~/.config/gh/hosts.yml`
- `CLAUDE_JSON` -> `~/.claude.json`
- `CODEX_AUTH_JSON` -> `~/.codex/auth.json`
- `GCLOUD_APPLICATION_DEFAULT_CREDENTIALS_JSON` -> `~/.config/gcloud/application_default_credentials.json`

## Rules

- Store actual secrets in 1Password.
- Commit templates and references only.
- Do not commit `~/.config/op/dotfiles.env`, `~/.config/op/dotfiles-files.env`, `.env`, token databases, private keys, or downloaded service-account JSON.
