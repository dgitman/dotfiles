#!/bin/bash
# Rebuild a new Mac from these dotfiles in one command:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dgitman/dotfiles/main/bootstrap.sh)"
#
# Installs Homebrew, 1Password, the 1Password CLI, and chezmoi, waits for the
# 1Password CLI integration to be enabled, then runs `chezmoi init --apply`.
# Safe to re-run: completed steps are skipped.
set -euo pipefail

REPO="${DOTFILES_REPO:-dgitman/dotfiles}"

info() { printf '\n==> %s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "this bootstrap only supports macOS."
[ "$(id -u)" -ne 0 ] || fail "run as your normal user, not root."

# 1. Homebrew (its installer also installs the Xcode Command Line Tools).
if ! command -v brew >/dev/null 2>&1; then
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$candidate" ] && eval "$("$candidate" shellenv)" && break
  done
fi
if ! command -v brew >/dev/null 2>&1; then
  info "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$candidate" ] && eval "$("$candidate" shellenv)" && break
  done
  command -v brew >/dev/null 2>&1 || fail "Homebrew installed but brew is not on PATH."
fi

# 2. 1Password app, 1Password CLI, and chezmoi. Names match dot_Brewfile so the
#    later `brew bundle` sees them as already installed.
if [ ! -d "/Applications/1Password.app" ]; then
  info "Installing 1Password"
  brew install --cask 1password
fi
if ! command -v op >/dev/null 2>&1; then
  info "Installing 1Password CLI"
  brew install --cask 1password-cli@beta
fi
if ! command -v chezmoi >/dev/null 2>&1; then
  info "Installing chezmoi"
  brew install chezmoi
fi

# 3. chezmoi templates read secrets with onepasswordRead, which needs the
#    desktop app unlocked and its CLI integration turned on.
if ! op vault list >/dev/null 2>&1; then
  info "Set up 1Password"
  cat <<'EOF'
  1. Sign in to 1Password and unlock it.
  2. Settings > Developer: turn on "Integrate with 1Password CLI".
  3. Settings > Developer: turn on "Use the SSH agent" (for git over SSH).
EOF
  open -a 1Password || true
  until op vault list >/dev/null 2>&1; do
    read -r -p "Press Return once 1Password is unlocked and the CLI integration is on... " _ </dev/tty
  done
fi
echo "1Password CLI is connected."

# 4. Clone and apply. HTTPS needs no SSH key; the remote is switched to SSH
#    afterwards so brewfile-sync can push through the 1Password SSH agent.
info "Applying dotfiles from github.com/$REPO"
if [ -d "$(chezmoi source-path 2>/dev/null || echo /nonexistent)" ]; then
  apply_cmd=(chezmoi apply)
else
  apply_cmd=(chezmoi init --apply "https://github.com/$REPO.git")
fi
if ! "${apply_cmd[@]}"; then
  cat <<'EOF' >&2

chezmoi apply stopped before finishing. Read the message above. Common causes
on a new Mac: an app-preference hook (Magnet, Grok Bot, Afterglow) asks you to
open that app once and quit it. Do that, then rerun this script or
`chezmoi apply`; finished steps are skipped.
EOF
  exit 1
fi
chezmoi git -- remote set-url origin "git@github.com:$REPO.git"

info "Done"
cat <<'EOF'
Next steps (see README "Post-rebuild checklist"):
  - Open a new terminal and run: dotfiles-setup
  - Restore pipx packages and personal background jobs as described in the README
  - Check with: chezmoi status && chezmoi doctor
EOF
