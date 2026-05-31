export HOMEBREW_BREWFILE="$HOME/dotfiles/brew/Brewfile"
export HOMEBREW_BUNDLE_FILE="$HOME/dotfiles/brew/Brewfile"
export HOMEBREW_BREWFILE_DESCRIBE=1
export HOMEBREW_BREWFILE_VSCODE=1
export CODEX_HOME="$HOME/.codex"

typeset -U path fpath

path_prepend() {
  [ -d "$1" ] || return
  path=("$1" $path)
}

path_prepend "$HOME/.local/bin"
path_prepend "$HOME/.antigravity/antigravity/bin"
path_prepend "$HOME/.antigravity-ide/antigravity-ide/bin"

if type brew &>/dev/null; then
  brew_prefix="$(brew --prefix)"
  path_prepend "$brew_prefix/bin"

  if [ -d "$brew_prefix/share/zsh-completions" ]; then
    fpath=("$brew_prefix/share/zsh-completions" $fpath)
  fi

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

alias d="cd ~/Developer"
