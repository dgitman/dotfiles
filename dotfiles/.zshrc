if [ -d "$HOME/bin" ]; then
  case ":$PATH:" in
    *":$HOME/bin:"*) ;;
    *) export PATH="$HOME/bin:$PATH" ;;
  esac
fi

export HOMEBREW_BREWFILE="$HOME/.config/brewfile/Brewfile"
export HOMEBREW_BUNDLE_FILE="$HOME/.config/brewfile/Brewfile"
export HOMEBREW_BREWFILE_DESCRIBE=1
export HOMEBREW_BREWFILE_VSCODE=1

if type brew &>/dev/null; then
  brew_prefix="$(brew --prefix)"
  FPATH="$brew_prefix/share/zsh-completions:$FPATH"

  autoload -Uz compinit
  compinit

  if [ -f "$brew_prefix/etc/brew-wrap" ]; then
    source "$brew_prefix/etc/brew-wrap"

    _post_brewfile_update() {
      local brewfile_dir="${HOMEBREW_BREWFILE%/*}"

      git -C "$brewfile_dir" add Brewfile
      if git -C "$brewfile_dir" diff --cached --quiet; then
        return
      fi

      git -C "$brewfile_dir" commit -m "Brewfile update"
      git -C "$brewfile_dir" push
    }
  fi
fi

if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init - zsh)"
fi

alias d="cd ~/Developer"
