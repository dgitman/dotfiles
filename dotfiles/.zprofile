if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init - --no-rehash zsh)"
fi

# Prefer XDG-style personal bin
export PATH="$HOME/.local/bin:$PATH"
