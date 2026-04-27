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

## Rules

- Store actual secrets in 1Password.
- Commit templates and references only.
- Do not commit `~/.config/op/dotfiles.env`, `.env`, token databases, private keys, or downloaded service-account JSON.
