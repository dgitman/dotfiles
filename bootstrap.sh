#!/bin/bash
# Rebuild a new Mac from these dotfiles in one command:
#   curl -fsSL https://raw.githubusercontent.com/dgitman/dotfiles/main/bootstrap.sh | bash
#
# Installs Homebrew, 1Password, the 1Password CLI, and chezmoi, waits for the
# 1Password CLI integration to be enabled, then runs `chezmoi init --apply`.
# Safe to re-run: completed steps are skipped.
set -euo pipefail

REPO="${DOTFILES_REPO:-dgitman/dotfiles}"

info() { printf '\n==> %s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

load_brew() {
  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$candidate" ]; then
      eval "$("$candidate" shellenv)"
      return
    fi
  done
}

main() {
  [ "$(uname -s)" = "Darwin" ] || fail "this bootstrap only supports macOS."
  [ "$(id -u)" -ne 0 ] || fail "run as your normal user, not root."

  # 1. Homebrew (its installer also installs the Xcode Command Line Tools).
  command -v brew >/dev/null 2>&1 || load_brew
  if ! command -v brew >/dev/null 2>&1; then
    info "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    load_brew
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
  # `op account list` never prompts; with no accounts, other op commands offer
  # to add one by hand, which is not wanted here.
  if [ -z "$(op account list </dev/null 2>/dev/null)" ]; then
    info "Set up 1Password"
    echo "  1. Sign in to 1Password and unlock it."
    echo "  2. Settings > Developer: turn on \"Integrate with 1Password CLI\"."
    echo "  3. Settings > Developer: turn on \"Use the SSH agent\" (for git over SSH)."
    echo "  If it is still not detected, quit 1Password fully (Cmd-Q), reopen, and unlock."
    open -a 1Password || true
  fi
  local answer
  while true; do
    if [ -z "$(op account list </dev/null 2>/dev/null)" ]; then
      echo "1Password CLI sees no accounts yet (app locked or CLI integration off)."
    else
      echo "Checking 1Password access; approve the request if 1Password asks..."
      # Errors stay visible so a failure says why.
      op vault list >/dev/null && break
    fi
    read -r -p "Press Return to check again, or type s to skip this check: " answer
    if [ "$answer" = "s" ]; then
      echo "Skipping the check; chezmoi will ask 1Password for access itself."
      break
    fi
  done
  echo "Continuing with 1Password."

  # 4. Clone and apply. HTTPS needs no SSH key; the remote is switched to SSH
  #    afterwards so brewfile-sync can push through the 1Password SSH agent.
  info "Applying dotfiles from github.com/$REPO"
  local apply_cmd=(chezmoi init --apply "https://github.com/$REPO.git")
  if [ -d "$(chezmoi source-path 2>/dev/null || echo /nonexistent)" ]; then
    apply_cmd=(chezmoi apply)
  fi
  if ! "${apply_cmd[@]}"; then
    echo >&2
    echo "chezmoi apply stopped before finishing. Fix what the message above names" >&2
    echo "(for an app-preference hook: open that app once and quit it), then rerun" >&2
    echo "this script or \`chezmoi apply\`; finished steps are skipped." >&2
    exit 1
  fi
  chezmoi git -- remote set-url origin "git@github.com:$REPO.git"

  info "Done"
  echo "Next steps (see README \"Post-rebuild checklist\"):"
  echo "  - Open a new terminal and run: dotfiles-setup"
  echo "  - Restore pipx packages and personal background jobs as described in the README"
  echo "  - Check with: chezmoi status && chezmoi doctor"
}

# Under `curl | bash`, stdin is the script itself. bash reads this whole file
# before main runs, and main reads from the terminal so the Homebrew, sudo, and
# chezmoi prompts work. A truncated download never reaches this line.
main "$@" </dev/tty
