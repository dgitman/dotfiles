if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init - --no-rehash zsh)"
fi

# Prefer XDG-style personal bin
export PATH="$HOME/.local/bin:$PATH"

# Add $HOME/bin to PATH (legacy, if present)
if [ -d "$HOME/bin" ]; then
  case ":$PATH:" in
    *":$HOME/bin:"*) ;;
    *) export PATH="$HOME/bin:$PATH" ;;
  esac
fi

# Add ~/dotfiles/brew to PATH
if [ -d "$HOME/dotfiles/brew" ]; then
  case ":$PATH:" in
    *":$HOME/dotfiles/brew:"*) ;;
    *) export PATH="$HOME/dotfiles/brew:$PATH" ;;
  esac
fi
