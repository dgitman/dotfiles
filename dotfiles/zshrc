if [ -d "$HOME/bin" ]; then
  case ":$PATH:" in
    *":$HOME/bin:"*) ;;
    *) export PATH="$HOME/bin:$PATH" ;;
  esac
fi

export HOMEBREW_BREWFILE="$HOME/.config/brewfile/Brewfile"
export HOMEBREW_BUNDLE_FILE="$HOME/.config/brewfile/Brewfile"

if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH

  autoload -Uz compinit
  compinit
fi

if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init - zsh)"
fi

alias d="cd ~/Developer"
