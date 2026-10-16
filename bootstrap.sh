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

# Verify the restored Google Cloud account can get an access token; offer
# sign-in if not. Tokens are discarded, never printed. Returns nonzero when
# sign-in is incomplete.
gcloud_signin() {
  if ! command -v gcloud >/dev/null 2>&1; then
    echo "Google Cloud CLI is missing; skipping sign-in."
    return 1
  fi
  local account answer
  account=$(gcloud config get-value core/account 2>/dev/null || true)
  if [ -z "$account" ] || [ "$account" = "(unset)" ]; then
    echo "No Google Cloud account is configured; skipping sign-in."
    return 1
  fi
  if gcloud auth print-access-token --account="$account" --quiet >/dev/null 2>&1; then
    echo "Google Cloud authentication works for $account."
    return 0
  fi
  echo "Google Cloud authentication could not be verified for $account"
  echo "(missing or expired credentials, connectivity, or account restrictions)."
  read -r -p "Sign in to Google Cloud now? [y/N] " answer
  case "$answer" in
    y|Y|yes|YES)
      # Shows a link to open in your preferred browser.
      gcloud auth login "$account" --no-launch-browser &&
        gcloud auth print-access-token --account="$account" --quiet >/dev/null &&
        echo "Google Cloud authentication verified."
      ;;
    *) return 1 ;;
  esac
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
    brew install --cask 1password-cli
  fi
  if ! command -v chezmoi >/dev/null 2>&1; then
    info "Installing chezmoi"
    brew install chezmoi
  fi

  # 3. chezmoi templates read secrets with onepasswordRead, which needs the
  #    desktop app unlocked and its CLI integration turned on.
  info "Set up 1Password"
  echo "  1. Sign in to 1Password and unlock it."
  echo "  2. Settings > Developer: turn on \"Integrate with 1Password CLI\"."
  echo "  3. Settings > Developer: turn on \"Use the SSH agent\" (for git over SSH)."
  open -a 1Password || true
  read -r -p "Press Return when done... " _

  # One op call so macOS asks for Terminal's access to 1Password data now,
  # not partway through chezmoi apply. Errors stay visible.
  echo "Connecting to 1Password. If macOS asks to let Terminal access data from"
  echo "other apps, click Allow; approve in 1Password if it asks."
  if ! op vault list >/dev/null; then
    echo "1Password CLI is not connected yet. Check: System Settings > Privacy &"
    echo "Security > Files & Folders > Terminal > \"Data shared by 1Password Launcher"
    echo "and affiliated apps\" is on, and the 1Password steps above are done."
    echo "The setting applies to new Terminal windows only: open a new window"
    echo "(Cmd-N) and run the bootstrap command again there."
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders" || true
    exit 1
  fi

  # 4. Clone and apply. HTTPS needs no SSH key; the remote is switched to SSH
  #    afterwards so brewfile-sync can push through the 1Password SSH agent.
  info "Applying dotfiles from github.com/$REPO"
  local apply_cmd=(chezmoi init --apply "https://github.com/$REPO.git")
  if [ -d "$(chezmoi source-path 2>/dev/null || echo /nonexistent)" ]; then
    apply_cmd=(chezmoi update)  # pull fixes pushed since the last run, then apply
  fi
  if ! "${apply_cmd[@]}"; then
    echo >&2
    echo "chezmoi apply stopped before finishing. Fix what the message above names" >&2
    echo "(for an app-preference hook: open that app once and quit it), then rerun" >&2
    echo "this script or \`chezmoi apply\`; finished steps are skipped." >&2
    exit 1
  fi
  chezmoi git -- remote set-url origin "git@github.com:$REPO.git"

  # 5. Google Cloud sign-in. It exits at once when already signed in; a declined
  #    or failed sign-in does not undo the restore.
  info "Checking Google Cloud sign-in"
  gcloud_signin || echo "Google Cloud sign-in not finished; run: gcloud auth login"

  info "Done"
  echo "Next steps (see README \"Post-rebuild checklist\"):"
  echo "  - Restore pipx packages and personal background jobs as described in the README"
  echo "  - Check with: chezmoi status && chezmoi doctor"
}

# Under `curl | bash`, stdin is the script itself. bash reads this whole file
# before main runs, and main reads from the terminal so the Homebrew, sudo, and
# chezmoi prompts work. A truncated download never reaches this line.
main "$@" </dev/tty
