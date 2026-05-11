export HOMEBREW_BREWFILE="$HOME/dotfiles/brew/Brewfile"
export HOMEBREW_BUNDLE_FILE="$HOME/dotfiles/brew/Brewfile"
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


#
alias d="cd ~/Developer"


