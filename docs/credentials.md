# Credentials

Keep live credentials out of Git, even when this repository is private. Store secret values in 1Password, then restore authenticated tool state locally.

## GitHub CLI

Track `config/gh/config.yml` for non-secret preferences. Do not track `~/.config/gh/hosts.yml`; it contains the GitHub CLI authentication token.

Preferred restore path:

```sh
gh auth login -h github.com
```

If you keep a GitHub token in 1Password, copy it from 1Password and use:

```sh
gh auth login --with-token
```

## Google Cloud

Track `config/gcloud/active_config` and `config/gcloud/configurations/config_default` for the selected account/config name. Do not track token databases, ADC JSON, boto files, logs, or virtual environments from `~/.config/gcloud`.

Preferred restore path:

```sh
gcloud auth login
gcloud auth application-default login
```

If a service account key is ever needed, store the JSON in 1Password and write it to a local ignored path only when needed.

## 1Password CLI

The `op` CLI is installed on this Mac. For scripts that need secrets, prefer 1Password secret references or `op read` at runtime rather than committed secret files.
