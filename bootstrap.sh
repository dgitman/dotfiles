#!/bin/bash
# Rebuild a new Mac from these dotfiles in one command:
#   curl -fsSL https://raw.githubusercontent.com/dgitman/dotfiles/main/bootstrap.sh | bash
#
# Installs Homebrew, 1Password, the 1Password CLI, and chezmoi, waits for the
# 1Password CLI integration to be enabled, then runs `chezmoi init --apply`.
# Safe to re-run: completed steps are skipped.
set -euo pipefail

REPO="${DOTFILES_REPO:-dgitman/dotfiles}"
REPO_OWNERS=(dgitman because-ventures)   # cloned to ~/Developer/<owner>/<repo>
PRINTER_QUEUE="Brother_HL_L2460DW"       # must match private_dot_cups/lpoptions
AFTER_DARK_URL="https://archive.org/download/Macintosh_Garden_Apps_Collection_A/After_Dark_10th_Anniversary.cdr_.zip/After%20Dark%2010th%20Anniversary.cdr"

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

# Clone every non-archived repo of each owner that is not already present.
clone_repos() {
  local owner repo dir names cloned=0
  # First connection to github.com: record its host key instead of prompting.
  export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new"
  for owner in "${REPO_OWNERS[@]}"; do
    # The wrapper gets the GitHub token from 1Password.
    if ! names=$("$HOME/.local/bin/gh" repo list "$owner" --no-archived --limit 1000 \
        --json name --jq '.[].name'); then
      echo "Could not list $owner repos; skipping them."
      continue
    fi
    for repo in $names; do
      [ "$owner/$repo" = "$REPO" ] && continue  # already the chezmoi source
      dir="$HOME/Developer/$owner/$repo"
      [ -e "$dir" ] && continue
      mkdir -p "$HOME/Developer/$owner"
      if git clone --quiet "git@github.com:$owner/$repo.git" "$dir" </dev/null; then
        echo "Cloned $owner/$repo"
        cloned=$((cloned + 1))
      else
        echo "Could not clone $owner/$repo."
      fi
    done
  done
  echo "$cloned new repos cloned into ~/Developer."
}

# Add the Brother printer over AirPrint (no driver needed) if it is on the network.
add_printer() {
  local uri
  if lpstat -p "$PRINTER_QUEUE" >/dev/null 2>&1; then
    echo "Printer $PRINTER_QUEUE is already set up."
    return 0
  fi
  uri=$(ippfind -T 5 --name 'L2460' 2>/dev/null | head -n 1)
  if [ -z "$uri" ]; then
    echo "No Brother HL-L2460DW found on this network; skipping."
    return 1
  fi
  lpadmin -p "$PRINTER_QUEUE" -E -v "$uri" -m everywhere -D "Brother HL-L2460DW" 2>/dev/null ||
    sudo lpadmin -p "$PRINTER_QUEUE" -E -v "$uri" -m everywhere -D "Brother HL-L2460DW"
  echo "Added printer $PRINTER_QUEUE ($uri)."
}

# Download the After Dark 10th Anniversary disc image once, mount it, and open
# Afterglow for the module import. The downloaded image marks this as done.
after_dark_modules() {
  local image="$HOME/Downloads/After Dark 10th Anniversary.cdr" answer
  if [ -f "$image" ]; then
    echo "After Dark image already downloaded ($image); skipping."
    return 0
  fi
  read -r -p "Download After Dark 10th Anniversary from archive.org for Afterglow? [y/N] " answer
  case "$answer" in y|Y|yes|YES) ;; *) echo "Skipped."; return 0 ;; esac
  curl -fL --progress-bar -o "$image.part" "$AFTER_DARK_URL" || {
    rm -f "$image.part"; echo "Download failed."; return 1; }
  mv "$image.part" "$image"
  hdiutil attach "$image" || return 1
  open -a Afterglow || true
  echo "In Afterglow, import the modules (Hall of Fame, Toaster 2k) from the mounted"
  echo "After Dark disk, then quit Afterglow and run: chezmoi apply"
}

# Set up Remtasks and Messages Sync from their clones in ~/Developer. Steps that
# are done are skipped. Full Disk Access cannot be requested by a script, so the
# settings page and the files to add are opened for you. Starting the sync jobs
# writes to Google, so it is asked for explicitly.
background_jobs() {
  local uid answer
  uid=$(id -u)
  local rem_repo="$HOME/Developer/dgitman/apple-reminders-google-tasks-sync"
  local rem_bin="$HOME/Library/Application Support/remtasks/Apple Reminders & Google Tasks Sync"
  local msg_repo="$HOME/Developer/dgitman/gitman-messages-sync"
  local msg_label="com.davidgitman.gitman-messages-sync"
  local rem_loaded=false msg_loaded=false
  launchctl print "gui/$uid/net.gitman.remtasks" >/dev/null 2>&1 && rem_loaded=true
  launchctl print "gui/$uid/$msg_label.incremental" >/dev/null 2>&1 && msg_loaded=true
  if $rem_loaded && $msg_loaded; then
    echo "Remtasks and Messages Sync agents are loaded."
    return 0
  fi

  # Install what is missing.
  if ! $rem_loaded && [ -d "$rem_repo" ] && [ ! -x "$rem_bin" ]; then
    echo "Building Remtasks (macOS asks for your password to trust its signing certificate)..."
    "$rem_repo/scripts/make-signing-identity.sh" && "$rem_repo/scripts/install.sh" ||
      echo "Remtasks install did not finish; see $rem_repo/README.md."
  fi
  if ! $msg_loaded && [ -d "$msg_repo" ] && [ ! -x "$msg_repo/.venv/bin/gitman-messages-sync" ]; then
    echo "Setting up the Messages Sync Python environment..."
    (cd "$msg_repo" && "$(brew --prefix)/bin/python3" -m venv .venv &&
      .venv/bin/python -m pip install --quiet --upgrade pip &&
      .venv/bin/python -m pip install --quiet -e .) ||
      echo "Messages Sync install did not finish; see $msg_repo/README.md."
  fi

  # Full Disk Access: open the page and show the files to drag into the list.
  echo "Full Disk Access: in the System Settings page that opens, drag in the files"
  echo "shown in Finder (or press + and add them), and turn on Terminal for manual runs."
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" || true
  if ! $rem_loaded && [ -x "$rem_bin" ]; then
    open -R "$rem_bin" || true
  fi
  if ! $msg_loaded && [ -d "$msg_repo/scripts" ]; then
    open -R "$msg_repo/scripts/Gitman Messages Sync Hourly" || true
    echo "  Messages Sync launchers: both \"Gitman Messages Sync\" files in $msg_repo/scripts"
  fi
  read -r -p "Press Return when Full Disk Access is set... " _

  # Remtasks: check, then offer to start its agent.
  if ! $rem_loaded && [ -x "$rem_bin" ]; then
    echo "Running remtasks doctor (allow Reminders access if macOS asks)..."
    "$HOME/.local/bin/remtasks" doctor ||
      echo "A \"Reminders database not readable\" FAIL here is expected unless Terminal has Full Disk Access; the agent uses the app's own access."
    read -r -p "Start Remtasks background sync on this Mac? Stop it on the old Mac first. [y/N] " answer
    case "$answer" in
      y|Y|yes|YES) "$HOME/.local/bin/remtasks" install-agent --interval 300 || true ;;
      *) echo "Not started. Later: remtasks install-agent --interval 300" ;;
    esac
  fi

  # Messages Sync: read-only source check, timezone check, then offer to load its jobs.
  if ! $msg_loaded && [ -x "$msg_repo/.venv/bin/gitman-messages-sync" ]; then
    echo "Checking the Messages database (read-only, no Google access)..."
    "$msg_repo/scripts/run.sh" validate-source ||
      echo "Check could not read Messages from Terminal. Expected unless Terminal has Full Disk Access; the jobs use the launchers' access."
    local tz; tz=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')
    [ "$tz" = "America/New_York" ] || echo "Warning: Mac timezone is $tz; Messages Sync expects America/New_York."
    read -r -p "Load the Messages Sync jobs (live writes to Sheets/Drive)? Stop them on the old Mac first. [y/N] " answer
    case "$answer" in
      y|Y|yes|YES)
        mkdir -p "$HOME/Library/Logs/GitmanMessagesSync"
        launchctl bootstrap "gui/$uid" "$HOME/Library/LaunchAgents/$msg_label.incremental.plist" || true
        launchctl enable "gui/$uid/$msg_label.reconcile" || true
        launchctl bootstrap "gui/$uid" "$HOME/Library/LaunchAgents/$msg_label.reconcile.plist" || true
        ;;
      *) echo "Not loaded. See README \"Restoring personal background jobs\"." ;;
    esac
  fi
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

  # 5. Steps the README used to list as manual.
  info "Cloning GitHub repos"
  clone_repos || echo "Repo cloning did not finish; re-run to retry."

  info "Adding the printer"
  add_printer || true

  info "After Dark modules for Afterglow"
  after_dark_modules || echo "Get the modules later; see README \"Afterglow preferences\"."

  info "Checking the restore"
  local drift
  drift=$(chezmoi status 2>&1 || true)
  if [ -n "$drift" ]; then
    echo "chezmoi status reports differences:"
    echo "$drift"
  else
    echo "chezmoi status: everything applied."
  fi
  chezmoi doctor 2>&1 | grep -Ev '^(ok|info|RESULT) ' || true

  # 6. Google Cloud sign-in. It exits at once when already signed in; a declined
  #    or failed sign-in does not undo the restore.
  info "Checking Google Cloud sign-in"
  gcloud_signin || echo "Google Cloud sign-in not finished; run: gcloud auth login"

  info "Personal background jobs"
  background_jobs || true

  info "Done"
}

# Under `curl | bash`, stdin is the script itself. bash reads this whole file
# before main runs, and main reads from the terminal so the Homebrew, sudo, and
# chezmoi prompts work. A truncated download never reaches this line.
main "$@" </dev/tty
