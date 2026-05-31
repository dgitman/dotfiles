export HOMEBREW_BREWFILE="$HOME/dotfiles/brew/Brewfile"
export HOMEBREW_BUNDLE_FILE="$HOME/dotfiles/brew/Brewfile"
export HOMEBREW_BREWFILE_DESCRIBE=1
export HOMEBREW_BREWFILE_VSCODE=1

if type brew &>/dev/null; then
  brew_prefix="$(brew --prefix)"
  FPATH="$brew_prefix/share/zsh-completions:$FPATH"

  autoload -Uz compinit
  compinit

  brew() {
    command brew "$@"
    local status=$?

    if [ "$status" -eq 0 ]; then
      case "${1:-}" in
        install|uninstall|remove|rm|reinstall|tap|untap)
          make -C "$HOME/dotfiles" brew-update
          ;;
      esac
    fi

    return "$status"
  }
fi


#
alias d="cd ~/Developer"


export PATH="$HOME/.local/bin:$PATH"

# Added by Antigravity
export PATH="/Users/dgitman/.antigravity/antigravity/bin:$PATH"

# Added by Antigravity IDE
export PATH="/Users/dgitman/.antigravity-ide/antigravity-ide/bin:$PATH"

export CODEX_HOME="$HOME/.codex"
